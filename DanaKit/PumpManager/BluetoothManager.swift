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

enum EncryptionType: UInt8 {
    case DEFAULT = 0
    case RSv3 = 1
    case BLE_5 = 2
}

class BluetoothManager : NSObject {
    
    private let log = OSLog(category: "BluetoothManager")
    
    private let okCharCodes: [UInt8] = [0x4f, 0x4b] // O, K
    private let pumpCharCodes: [UInt8] = [0x50, 0x55, 0x4d, 0x50] // P, U, M, P
    private let busyCharCodes: [UInt8] = [0x42, 0x55, 0x53, 0x59] // B, U, S, Y
    
    private let deviceNameRegex = try! NSRegularExpression(pattern: "^[a-zA-Z]{3}[0-9]{5}[a-zA-Z]{2}$")
    private var connectedDevice: CBPeripheral!
    
    private let PACKET_START_BYTE: UInt8 = 0xa5
    private let PACKET_END_BYTE: UInt8 = 0x5a
    private let ENCRYPTED_START_BYTE: UInt8 = 0xaa
    private let ENCRYPTED_END_BYTE: UInt8 = 0xee
    
    private let SERVICE_UUID = CBUUID(string: "FFF0")
    private let READ_CHAR_UUID = CBUUID(string: "FFF1")
    private var readCharacteristic: CBCharacteristic!
    private let WRITE_CHAR_UUID = CBUUID(string: "FFF2")
    private var writeCharacteristic: CBCharacteristic!
    
    private var encryptionMode: EncryptionType = .DEFAULT {
        didSet {
            log.debug("%{public}@: %{public}@", #function, encryptionMode.rawValue)
            DanaRSEncryption.setEnhancedEncryption(encryptionMode.rawValue)
        }
    }
    
    private var manager: CBCentralManager! = nil
    private let managerQueue = DispatchQueue(label: "com.DanaKit.bluetoothManagerQueue", qos: .unspecified)
    
    private var state: DanaKitPumpManagerState
    private var readBuffer = Data([])
    
    private var devices: [CBPeripheral] = []

    init(_ state: DanaKitPumpManagerState) {
        self.state = state
        super.init()
        
        managerQueue.sync {
            self.manager = CBCentralManager(delegate: self, queue: managerQueue, options: [CBCentralManagerOptionRestoreIdentifierKey: "com.DanaKit"])
        }
    }
    
    func startScan() {
        manager.scanForPeripherals(withServices: [])
    }
}

// MARK: Central manager functions
extension BluetoothManager : CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        dispatchPrecondition(condition: .onQueue(managerQueue))
        
        log.default("%{public}@: %{public}@", #function, String(describing: central.state.rawValue))
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if (peripheral.name == nil || self.deviceNameRegex.firstMatch(in: peripheral.name!, range: NSMakeRange(0, peripheral.name!.count)) == nil) {
            return
        }
        
        dispatchPrecondition(condition: .onQueue(managerQueue))
        log.debug("%{public}@: %{public}@, %{public}@", #function, peripheral, advertisementData)
        
        var device: CBPeripheral? = devices.first(where: { $0.identifier == peripheral.identifier })
        if (device != nil) {
            return
        }
        
        devices.append(peripheral)
        
        if (self.state.autoConnect) {
            self.manager.stopScan()
            self.manager.connect(peripheral)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        dispatchPrecondition(condition: .onQueue(managerQueue))
        
        log.debug("%{public}@: %{public}@", #function, peripheral)
        self.encryptionMode = .DEFAULT
        
        self.state.deviceAddress = peripheral.identifier.uuidString
        self.state.deviceName = peripheral.name
        self.state.deviceIsRequestingPincode = false
        
        peripheral.discoverServices([SERVICE_UUID])
    }
}

// MARK: - peripheral functions
extension BluetoothManager : CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if (error != nil) {
            log.error("%{public}@: %{public}@", #function, error!.localizedDescription)
            self.manager.cancelPeripheralConnection(peripheral)
            return
        }
        
        let service = peripheral.services?.first(where: { $0.uuid == SERVICE_UUID })
        if (service == nil) {
            log.error("%{public}@: Failed to discover dana data service...", #function)
            self.manager.cancelPeripheralConnection(peripheral)
            return
        }
        
        peripheral.discoverCharacteristics([READ_CHAR_UUID, WRITE_CHAR_UUID], for: service!)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if (error != nil) {
            log.error("%{public}@: %{public}@", #function, error!.localizedDescription)
            self.manager.cancelPeripheralConnection(peripheral)
            return
        }
        
        let service = peripheral.services!.first(where: { $0.uuid == SERVICE_UUID })!
        self.readCharacteristic = service.characteristics?.first(where: { $0.uuid == READ_CHAR_UUID })
        self.writeCharacteristic = service.characteristics?.first(where: { $0.uuid == WRITE_CHAR_UUID })
        
        if (self.writeCharacteristic == nil || self.readCharacteristic == nil) {
            log.error("%{public}@: Failed to discover dana write or read characteristic", #function)
            self.manager.cancelPeripheralConnection(peripheral)
            return
        }
        
        peripheral.setNotifyValue(true, for: self.readCharacteristic)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor descriptor: CBDescriptor, error: Error?) {
        if (error != nil) {
            log.error("%{public}@: %{public}@", #function, error!.localizedDescription)
            self.manager.cancelPeripheralConnection(peripheral)
            return
        }
        
        self.sendFirstMessageEncryption()
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if (error != nil) {
            log.error("%{public}@: %{public}@", #function, error!.localizedDescription)
            self.manager.cancelPeripheralConnection(peripheral)
            return
        }
        
        guard let data = characteristic.value else {
            return
        }
        
        self.parseReceivedValue(data)
    }
    
    private func writeQ(_ data: Data) {
        if (self.connectedDevice == nil) {
            log.error("%{public}@: Not connected to Dana pump...", #function)
            return
        }
        
        log.debug("%{public}@: %{public}@, %{public}@", #function, self.connectedDevice, data.base64EncodedString())
        self.connectedDevice.writeValue(data, for: self.writeCharacteristic, type: .withoutResponse)
    }
}

// MARK: - Encryption/Connection functions
extension BluetoothManager {
    private func sendFirstMessageEncryption() {
        let data = DanaRSEncryption.encodePacket(operationCode: DanaPacketType.OPCODE_ENCRYPTION__PUMP_CHECK, buffer: nil, deviceName: self.state.deviceName ?? "")
        
        log.debug("%{public}@: Sending Initial encryption request. Data: %{public}@", #function, data.base64EncodedString())
        self.writeQ(data)
    }
    
    private func sendTimeInfo() {
        let data = DanaRSEncryption.encodePacket(operationCode: DanaPacketType.OPCODE_ENCRYPTION__TIME_INFORMATION, buffer: nil, deviceName: self.state.deviceName ?? "")
        
        log.debug("%{public}@: Sending normal time information. Data: %{public}@", #function, data.base64EncodedString())
        self.writeQ(data)
    }
    
    private func sendV3PairingInformation(_ requestNewPairing: UInt8) {
        let data = DanaRSEncryption.encodePacket(operationCode: DanaPacketType.OPCODE_ENCRYPTION__TIME_INFORMATION, buffer: Data([requestNewPairing]), deviceName: self.state.deviceName ?? "")
        
        log.debug("%{public}@: Sending RSv3 time information. Data: %{public}@", #function, data.base64EncodedString())
        self.writeQ(data)
    }
    
    private func sendV3PairingInformationEmpty() {
        let (pairingKey, randomPairingKey) = DanaRSEncryption.getPairingKeys()
        
        let command: UInt8 = pairingKey.count == 0 || randomPairingKey.count == 0 ? 1 : 0
        self.sendV3PairingInformation(command)
    }
    
    private func sendPairingRequest() {
        let data = DanaRSEncryption.encodePacket(operationCode: DanaPacketType.OPCODE_ENCRYPTION__PASSKEY_REQUEST, buffer: nil, deviceName: self.state.deviceName ?? "")
        
        log.debug("%{public}@: Sending pairing request. Data: %{public}@", #function, data.base64EncodedString())
        self.writeQ(data)
    }
    
    private func sendEasyMenuCheck() {
        let data = DanaRSEncryption.encodePacket(operationCode: DanaPacketType.OPCODE_ENCRYPTION__GET_EASYMENU_CHECK, buffer: nil, deviceName: self.state.deviceName ?? "")
        
        log.debug("%{public}@: Sending easy menu check. Data: %{public}@", #function, data.base64EncodedString())
        self.writeQ(data)
    }
    
    private func sendBLE5PairingInformation() {
        let data = DanaRSEncryption.encodePacket(operationCode: DanaPacketType.OPCODE_ENCRYPTION__TIME_INFORMATION, buffer: Data([0, 0, 0, 0]), deviceName: self.state.deviceName ?? "")
        
        log.debug("%{public}@: Sending BLE5 time information. Data: %{public}@", #function, data.base64EncodedString())
        self.writeQ(data)
    }
    
    private func sendPassKeyCheck(_ pairingKey: Data) {
        let data = DanaRSEncryption.encodePacket(operationCode: DanaPacketType.OPCODE_ENCRYPTION__CHECK_PASSKEY, buffer: pairingKey, deviceName: self.state.deviceName ?? "")
        
        log.debug("%{public}@: Sending Passkey check. Data: %{public}@", #function, data.base64EncodedString())
        self.writeQ(data)
    }
    
    /// Used after entering PIN codes (only for DanaRS v3)
    func finishV3Pairing(_ pairingKey: Data, _ randomPairingKey: Data) {
        DanaRSEncryption.setPairingKeys(pairingKey: pairingKey, randomPairingKey: randomPairingKey, randomSyncKey: 0)
        self.sendV3PairingInformation(0)
    }
    
    private func processEasyMenuCheck(_ data: Data) {
        self.state.isEasyMode = data[2] == 0x01
        self.state.isUnitUD = data[3] == 0x01
        
        if (self.encryptionMode == .RSv3) {
            self.sendV3PairingInformationEmpty()
        } else {
            self.sendTimeInfo()
        }
    }
    
    private func processPairingRequest(_ data: Data) {
        if (data[2] == 0x00) {
            // Everything is order. Waiting for pump to send OPCODE_ENCRYPTION__PASSKEY_RETURN
            return
        }
        
        log.error("%{public}@: Passkey request failed. Data: %{public}@", #function, data.base64EncodedString())
        self.manager.cancelPeripheralConnection(self.connectedDevice)
    }
    
    private func processPairingRequest2(_ data: Data) {
        self.sendTimeInfo()
        
        let pairingKey = data.subdata(in: 2..<4)
        DanaRSEncryption.setPairingKeys(pairingKey: pairingKey, randomPairingKey: Data(), randomSyncKey: 0)
    }
    
    private func processConnectResponse(_ data: Data) {
        if (data.count == 4 && self.isOk(data)) {
            // response OK v1
            self.encryptionMode = .DEFAULT
            self.state.ignorePassword = false;
            
            let (pairingKey, _) = DanaRSEncryption.getPairingKeys()
            if (pairingKey.count > 0) {
                self.sendPassKeyCheck(pairingKey)
            } else {
                self.sendPairingRequest()
            }
        } else if (data.count == 9 && self.isOk(data)) {
            // response OK v3, 2nd layer encryption
            self.encryptionMode = .RSv3
            self.state.ignorePassword = true;
            
            self.state.hwModel = data[5]
            self.state.pumpProtocol = data[7]
            
            if (self.state.hwModel == 0x05) {
                self.sendV3PairingInformationEmpty()
            } else if (self.state.hwModel == 0x06) {
                self.sendEasyMenuCheck()
            } else {
                log.error("%{public}@: Got invalid hwModel ", #function, self.state.hwModel)
                self.manager.cancelPeripheralConnection(self.connectedDevice)
            }
        } else if (data.count == 14 && self.isOk(data)) {
            self.encryptionMode = .BLE_5
            
            self.state.hwModel = data[5]
            self.state.pumpProtocol = data[7]
            
            guard (self.state.hwModel == 0x09 || self.state.hwModel == 0x0a) else {
                log.error("%{public}@: Got invalid hwModel ", #function, self.state.hwModel)
                self.manager.cancelPeripheralConnection(self.connectedDevice)
                return
            }
            
            let ble5Keys = data.subdata(in: 8..<14)
            DanaRSEncryption.setBle5Key(ble5Key: ble5Keys)
            self.sendBLE5PairingInformation()
        } else if (data.count == 6 && self.isPump(data)) {
            log.error("%{public}@: PUMP_CHECK error. Data: %{public}@", data.base64EncodedString())
        } else if (data.count == 6 && isBusy(data)) {
            log.error("%{public}@: PUMP_CHECK_BUSY error. Data: %{public}@", data.base64EncodedString())
        } else {
            log.error("%{public}@: PUMP_CHECK error, wrong serial number. Data: %{public}@", data.base64EncodedString())
        }
    }
    
    private func processEncryptionResponse(_ data: Data) {
        if (self.encryptionMode == .BLE_5) {
            self.state.isConnected = true
            log.default("%{public}@: Connection & encryption successful!", #function)
        } else if (self.encryptionMode == .RSv3) {
            // data[2] : 0x00 OK  0x01 Error, No pairing
            if (data[2] == 0x00) {
                let (pairingKey, randomPairingKey) = DanaRSEncryption.getPairingKeys()
                if (pairingKey.count == 0 || randomPairingKey.count == 0) {
                    log.default("%{public}@: Device is requesting pincode")
                    self.state.deviceIsRequestingPincode = true
                    return
                }
                
                log.default("%{public}@: Connection & encryption successful!", #function)
                self.state.isConnected = true
            } else {
                self.sendV3PairingInformation(1)
            }
        } else {
            let highByte = UInt16((data[data.count - 1] & 0xff) << 8)
            let lowByte = UInt16(data[data.count - 2] & 0xff)
            let password = (highByte + lowByte) ^ 0x0d87
            if (password != self.state.devicePassword && !self.state.ignorePassword) {
                log.error("%{public}@: Invalid password")
                self.manager.cancelPeripheralConnection(self.connectedDevice)
                return
            }
            
            log.default("%{public}@: Connection & encryption successful! Name: %{public}@", #function, self.state.deviceName ?? "")
            self.state.isConnected = true
        }
    }
    
    private func isOk(_ data: Data) -> Bool {
        return data[2] == okCharCodes[0] && data[3] == okCharCodes[1]
    }
    
    private func isPump(_ data: Data) -> Bool {
        return data[2] == pumpCharCodes[0] && data[3] == pumpCharCodes[1] && data[4] == pumpCharCodes[2] && data[5] == pumpCharCodes[3]
    }
    
    private func isBusy(_ data: Data) -> Bool {
        return data[2] == busyCharCodes[0] && data[3] == busyCharCodes[1] && data[4] == busyCharCodes[2] && data[5] == busyCharCodes[3]
    }
}

// MARK: Parsers for incomming messages
extension BluetoothManager {
    private func parseReceivedValue(_ receievedData: Data) {
        var data = receievedData
        if (self.state.isConnected && self.encryptionMode != .DEFAULT) {
            data = DanaRSEncryption.decodeSecondLevel(data: data)
        }
        
        self.readBuffer.append(data)
        guard (self.readBuffer.count >= 6) else {
            // Buffer is not ready to be processed
            return
        }
        
        if (
            !(self.readBuffer[0] == self.PACKET_START_BYTE || self.readBuffer[0] == self.ENCRYPTED_START_BYTE) ||
            !(self.readBuffer[1] == self.PACKET_START_BYTE || self.readBuffer[1] == self.ENCRYPTED_START_BYTE)
        ) {
            // The buffer does not start with the opening bytes. Check if the buffer is filled with old data
            if let indexStartByte = self.readBuffer.firstIndex(of: self.PACKET_START_BYTE) {
                self.readBuffer = self.readBuffer.subdata(in: indexStartByte..<self.readBuffer.count)
            } else if let indexEncryptedStartByte = self.readBuffer.firstIndex(of: self.ENCRYPTED_START_BYTE) {
                self.readBuffer = self.readBuffer.subdata(in: indexEncryptedStartByte..<self.readBuffer.count)
            } else {
                log.error("%{public}@: Received invalid packets. Starting bytes do not exists in message. Data: %{public}@", #function, data.base64EncodedString())
                self.readBuffer = Data([])
                return
            }
        }
        
        let length = Int(self.readBuffer[2])
        guard (length + 7 == self.readBuffer.count) else {
            // Not all packets have been received yet...
            return
        }
        
        guard (
            (self.readBuffer[length + 5] == self.PACKET_END_BYTE || self.readBuffer[length + 5] == self.ENCRYPTED_END_BYTE) &&
            (self.readBuffer[length + 6] == self.PACKET_END_BYTE || self.readBuffer[length + 6] == self.ENCRYPTED_END_BYTE)
          ) else {
            // Invalid packets received...
            log.error("%{public}@: Received invalid packets. Ending bytes do not match. Data: %{public}@", #function, data.base64EncodedString())
            self.readBuffer = Data([])
            return
          }
        
        log.debug("%{public}@: Received message! Starting to decrypt data: %{public}@", #function, data.base64EncodedString())
        let decryptedData = DanaRSEncryption.decodePacket(buffer: data, deviceName: self.state.deviceName ?? "")
        self.readBuffer = Data([])
        
        if (decryptedData[0] == DanaPacketType.TYPE_ENCRYPTION_RESPONSE) {
            log.debug("%{public}@: Decoding successful! Start processing encryption message. Data: %{public}@", #function, decryptedData.base64EncodedString())
            
            switch(decryptedData[1]) {
            case DanaPacketType.OPCODE_ENCRYPTION__PUMP_CHECK:
                self.processConnectResponse(decryptedData)
                return
            case DanaPacketType.OPCODE_ENCRYPTION__TIME_INFORMATION:
                self.processEncryptionResponse(decryptedData)
                return
            case DanaPacketType.OPCODE_ENCRYPTION__CHECK_PASSKEY:
                if (decryptedData[2] == 0x05) {
                    self.sendTimeInfo()
                } else {
                    self.sendPairingRequest()
                }
                return
            case DanaPacketType.OPCODE_ENCRYPTION__PASSKEY_REQUEST:
                self.processPairingRequest(decryptedData)
                return
            case DanaPacketType.OPCODE_ENCRYPTION__PASSKEY_RETURN:
                self.processPairingRequest2(decryptedData)
                return
            case DanaPacketType.OPCODE_ENCRYPTION__GET_PUMP_CHECK:
                if (decryptedData[2] == 0x05) {
                    self.sendTimeInfo()
                } else {
                    self.sendEasyMenuCheck()
                }
                return
            case DanaPacketType.OPCODE_ENCRYPTION__GET_EASYMENU_CHECK:
                self.processEasyMenuCheck(decryptedData)
                return
            default:
                log.error("%{public}@: Received invalid encryption command type %{public}@", #function, decryptedData[1])
                return
            }
        }
        
        guard(decryptedData[0] == DanaPacketType.TYPE_RESPONSE || decryptedData[0] == DanaPacketType.TYPE_NOTIFY) else {
            log.error("%{public}@: Received invalid packet type %{public}@", #function, decryptedData[0])
            return
        }
        
        log.debug("%{public}@: Decoding successful! Start processing normal (or notify) message. Data: %{public}@", #function, decryptedData.base64EncodedString())
        self.processMessage(data)
    }
    
    private func processMessage(_ data: Data) {
        // TODO: Implement this function with callback timeout
    }
}
