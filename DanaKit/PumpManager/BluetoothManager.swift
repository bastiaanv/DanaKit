//
//  BluetoothManager.swift
//  DanaKit
//
//  Created by Bastiaan Verhaar on 14/12/2023.
//  Copyright © 2023 Randall Knutson. All rights reserved.
//

import CoreBluetooth
import Foundation
import os.log
import SwiftUI

public struct DanaPumpScan {
    let bleIdentifier: String
    let name: String
    let peripheral: CBPeripheral
}

enum EncryptionType: UInt8 {
    case DEFAULT = 0
    case RSv3 = 1
    case BLE_5 = 2
}

class BluetoothManager : NSObject {
    
    private let log = OSLog(category: "BluetoothManager")
    
    private let deviceNameRegex = try! NSRegularExpression(pattern: "^[a-zA-Z]{3}[0-9]{5}[a-zA-Z]{2}$")
    
    private var manager: CBCentralManager! = nil
    private let managerQueue = DispatchQueue(label: "com.DanaKit.bluetoothManagerQueue", qos: .unspecified)
    
    private var pumpManager: DanaKitPumpManager
    private var peripheralManager: PeripheralManager?
    private var view: UIViewController?
    private var connectionCompletion: (Error?) -> Void = { _ in }
    
    private var devices: [DanaPumpScan] = []

    init(_ pumpManager: DanaKitPumpManager) {
        self.pumpManager = pumpManager
        super.init()
        
        managerQueue.sync {
            self.manager = CBCentralManager(delegate: self, queue: managerQueue, options: [CBCentralManagerOptionRestoreIdentifierKey: "com.DanaKit"])
        }
    }
    
    func startScan() throws {
        guard self.manager.state == .poweredOn else {
            throw NSError(domain: "Invalid bluetooth state. State: " + String(self.manager.state.rawValue), code: 0, userInfo: nil)
        }
        
        guard !self.manager.isScanning else {
            log.info("%{public}@: Device is already scanning...", #function)
            return
        }
        
        self.devices = []
        
        manager.scanForPeripherals(withServices: [])
        log.info("%{public}@: Started scanning", #function)
    }
    
    func stopScan() {
        manager.stopScan()
        self.devices = []
        
        log.info("%{public}@: Stopped scanning", #function)
    }
    
    func connect(_ bleIdentifier: String, _ view: UIViewController, _ completion: @escaping (Error?) -> Void) {
        guard let uuid = UUID(uuidString: bleIdentifier) else {
            completion(NSError(domain: "Invalid ble identifier", code: 0, userInfo: nil))
            return
        }
        
        let peripherals = manager.retrievePeripherals(withIdentifiers: [uuid])
        if (peripherals.count != 1) {
            completion(NSError(domain: "Device never connected", code: 0, userInfo: nil))
            return
        }
        
        if (self.peripheralManager != nil) {
            self.disconnect(peripherals.first!)
            self.peripheralManager = nil
        }
        
        manager.connect(peripherals.first!)
        
        self.view = view
        self.connectionCompletion = completion
    }
    
    func connect(_ peripheral: CBPeripheral, _ view: UIViewController, _ completion: @escaping (Error?) -> Void) {
        if (self.peripheralManager != nil) {
            self.disconnect(peripheral)
            self.peripheralManager = nil
        }
        
        manager.connect(peripheral)
        
        self.view = view
        self.connectionCompletion = completion
    }
    
    func disconnect(_ peripheral: CBPeripheral) {
        log.default("Disconnecting from pump...")
        self.manager.cancelPeripheralConnection(peripheral)
    }
    
    func writeMessage(_ packet: DanaGeneratePacket) async throws -> (any DanaParsePacketProtocol) {
        guard let peripheralManager = self.peripheralManager else {
            throw NSError(domain: "No connected device", code: 0, userInfo: nil)
        }
        
        return try await peripheralManager.writeMessage(packet)
    }
    
    func updateInitialState() async throws {
        guard let peripheralManager = self.peripheralManager else {
            throw NSError(domain: "No connected device", code: 0, userInfo: nil)
        }
        
        return await peripheralManager.updateInitialState()
    }
}

// MARK: Central manager functions
extension BluetoothManager : CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        dispatchPrecondition(condition: .onQueue(managerQueue))
        
        log.default("%{public}@: %{public}@", #function, String(describing: central.state.rawValue))
    }
    
    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String : Any]) {
        dispatchPrecondition(condition: .onQueue(managerQueue))
        log.info("%{public}@: %{public}@", #function, dict)
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if (peripheral.name == nil || self.deviceNameRegex.firstMatch(in: peripheral.name!, range: NSMakeRange(0, peripheral.name!.count)) == nil) {
            return
        }
        
        dispatchPrecondition(condition: .onQueue(managerQueue))
        log.debug("%{public}@: %{public}@, %{public}@", #function, peripheral, advertisementData)
        
        let device: DanaPumpScan? = devices.first(where: { $0.bleIdentifier == peripheral.identifier.uuidString })
        if (device != nil) {
            return
        }
        
        let result = DanaPumpScan(bleIdentifier: peripheral.identifier.uuidString, name: peripheral.name!, peripheral: peripheral)
        devices.append(result)
        self.pumpManager.notifyScanDeviceDidChange(result)
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        dispatchPrecondition(condition: .onQueue(managerQueue))
        
        guard let view = self.view else {
            log.error("%{public}@: No view found...", #function)
            self.disconnect(peripheral)
            return
        }
        
        log.debug("%{public}@: %{public}@", #function, peripheral)
        self.peripheralManager = PeripheralManager(peripheral, self, self.pumpManager, view, self.connectionCompletion)
        
        self.pumpManager.state.deviceName = peripheral.name
        self.pumpManager.notifyStateDidChange()
        
        peripheral.readRSSI()
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        log.default("%{public}@: Device disconnected, name: %{public}@", #function, peripheral.name ?? "<NO_NAME>")
        
        self.pumpManager.state.isConnected = false
        self.pumpManager.notifyStateDidChange()
    }
}
