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
    
    private var devices: [DanaPumpScan] = []

    init(_ pumpManager: DanaKitPumpManager) {
        self.pumpManager = pumpManager
        super.init()
        
        managerQueue.sync {
            self.manager = CBCentralManager(delegate: self, queue: managerQueue, options: [CBCentralManagerOptionRestoreIdentifierKey: "com.DanaKit"])
        }
    }
    
    func startScan() {
        self.devices = []
        
        manager.scanForPeripherals(withServices: [])
        log.info("%{public}@: Started scanning", #function)
    }
    
    func stopScan() {
        manager.stopScan()
        self.devices = []
        
        log.info("%{public}@: Stopped scanning", #function)
    }
    
    func connect(_ bleIdentifier: String) throws {
        guard let uuid = UUID(uuidString: bleIdentifier) else {
            throw NSError(domain: "Invalid ble identifier", code: 0, userInfo: nil)
        }
        
        let peripherals = manager.retrievePeripherals(withIdentifiers: [uuid])
        if (peripherals.count != 1) {
            throw NSError(domain: "Device never connected", code: 0, userInfo: nil)
        }
        
        if (self.peripheralManager != nil) {
            self.disconnect(peripherals.first!)
            self.peripheralManager = nil
        }
        
        manager.connect(peripherals.first!)
    }
    
    func connect(_ peripheral: CBPeripheral) {
        if (self.peripheralManager != nil) {
            self.disconnect(peripheral)
            self.peripheralManager = nil
        }
        
        manager.connect(peripheral)
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
    
    func finishV3Pairing(_ pairingKey: Data, _ randomPairingKey: Data) throws {
        guard let peripheralManager = self.peripheralManager else {
            throw NSError(domain: "No connected device", code: 0, userInfo: nil)
        }
        
        peripheralManager.finishV3Pairing(pairingKey, randomPairingKey)
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
        
        log.debug("%{public}@: %{public}@", #function, peripheral)
        self.peripheralManager = PeripheralManager(peripheral, self, self.pumpManager)
        
        self.pumpManager.state.deviceName = peripheral.name
        self.pumpManager.state.deviceIsRequestingPincode = false
        self.pumpManager.notifyStateDidChange()
        
        peripheral.readRSSI()
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        log.default("%{public}@: Device disconnected, name: %{public}@", #function, peripheral.name ?? "<NO_NAME>")
        
        self.pumpManager.state.isConnected = false
        self.pumpManager.notifyStateDidChange()
    }
}
