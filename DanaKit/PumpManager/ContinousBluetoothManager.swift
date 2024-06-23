//
//  ContinousBluetoothManager.swift
//  DanaKit
//
//  Created by Bastiaan Verhaar on 09/06/2024.
//  Copyright © 2024 Randall Knutson. All rights reserved.
//

import Foundation
import CoreBluetooth
import UserNotifications

class ContinousBluetoothManager : NSObject, BluetoothManager {
    var pumpManagerDelegate: DanaKitPumpManager? {
        didSet {
            self.autoConnectUUID = self.pumpManagerDelegate?.state.bleIdentifier
        }
    }
    
    var autoConnectUUID: String? = nil
    var connectionCompletion: ((ConnectionResult) -> Void)? = nil
    var connectionCallback: [String: ((ConnectionResultShort) -> Void)] = [:]
    var devices: [DanaPumpScan] = []
    
    let log = DanaLogger(category: "ContinousBluetoothManager")
    var manager: CBCentralManager! = nil
    let managerQueue = DispatchQueue(label: "com.DanaKit.bluetoothManagerQueue", qos: .unspecified)
    
    var peripheral: CBPeripheral?
    var peripheralManager: PeripheralManager?
    
    override init() {
        super.init()
        
        managerQueue.sync {
            self.manager = CBCentralManager(delegate: self, queue: managerQueue, options: [CBCentralManagerOptionRestoreIdentifierKey: "com.DanaKit"])
        }
    }
    
    private func keepConnectionAlive() async {
        do {
            self.log.info("Sending keep alive message")
            let keepAlivePacket = generatePacketGeneralKeepConnection()
            let result = try await self.writeMessage(keepAlivePacket)
            guard result.success else {
                self.log.error("Pump rejected keepAlive request: \(result.rawData.base64EncodedString())")
                return
            }
            
            Task {
                try await Task.sleep(nanoseconds: 30000000000) // Sleep for 30sec
                await self.keepConnectionAlive()
            }
        } catch {
            self.log.error("Failed to keep connection alive: \(error.localizedDescription)")
        }
    }
    
    public func reconnect(_ callback: @escaping (Bool) -> Void) {
        guard !self.isConnected else{
            callback(true)
            return
        }
        
        if self.peripheral != nil {
            self.connect(self.peripheral!) { result in
                switch(result) {
                case .success:
                    Task {
                        await self.keepConnectionAlive()
                        callback(true)
                    }
                    break;
                default:
                    self.log.error("Failed to reconnect: \(result)")
                    callback(false)
                }
            }
            return
        }
        
        if self.autoConnectUUID == nil {
            self.autoConnectUUID = self.pumpManagerDelegate?.state.bleIdentifier
        }
        
        guard let autoConnect = self.autoConnectUUID else {
            self.log.error("No autoConnect: \(String(describing: self.autoConnectUUID))")
            callback(false)
            return
        }
        
        do {
            try self.connect(autoConnect) { result in
                switch(result) {
                case .success:
                    Task {
                        await self.keepConnectionAlive()
                        callback(true)
                    }
                    break;
                default:
                    self.log.error("Failed to do auto connection: \(result)")
                    callback(false)
                }
            }
        } catch {
            log.error("Failed to auto connect: \(error.localizedDescription)")
            callback(false)
        }
    }
    
    func ensureConnected(_ completion: @escaping (ConnectionResultShort) async -> Void, _ identifier: String = #function) {
        Task {
            // Device still has an active connection with pump and is probably busy with something
            if self.isConnected {
                self.resetConnectionCompletion()
                self.logDeviceCommunication("Dana - Connection is ok!", type: .connection)
                await completion(.success)
                
            } else {
                // We aren't connected, the user has probably disconnected the pump by hand
                self.log.error("Device not connected...")
                self.logDeviceCommunication("Dana - Pump is not connected. Please reconnect to pump before doing any operations", type: .connection)
                
                self.resetConnectionCompletion()
                await completion(.failure)
            }
        }
    }
    
    func disconnect(_ peripheral: CBPeripheral, force: Bool) {
        guard force else {
            return
        }
        
        self.autoConnectUUID = nil
        
        logDeviceCommunication("Dana - Disconnected", type: .connection)
        self.manager.cancelPeripheralConnection(peripheral)
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        self.bleCentralManagerDidUpdateState(central)
        
        if central.state == .poweredOn {
            self.reconnect{ _ in }
        }
    }
    
    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String : Any]) {
        self.bleCentralManager(central, willRestoreState: dict)
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        self.bleCentralManager(central, didDiscover: peripheral, advertisementData: advertisementData, rssi: RSSI)
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        self.bleCentralManager(central, didConnect: peripheral)
        
        NotificationHelper.clearDisconnectWarning()
        NotificationHelper.clearDisconnectReminder()
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        self.bleCentralManager(central, didDisconnectPeripheral: peripheral, error: error)
        
        if let autoConnectUUID = self.autoConnectUUID {
            do {
                self.log.info("Connection lost. Trying to reconnect...")
                NotificationHelper.setDisconnectWarning()
                
                if self.peripheral?.identifier.uuidString == autoConnectUUID {
                    self.connect(self.peripheral!) { _ in }
                } else {
                    try self.connect(autoConnectUUID) { _ in }
                }
            } catch {
                self.log.error("Failed to auto reconnect: \(error.localizedDescription)")
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        self.bleCentralManager(central, didFailToConnect: peripheral, error: error)
    }
}
