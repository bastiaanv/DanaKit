//
//  BluetoothManager.swift
//  DanaKit
//
//  Created by Bastiaan Verhaar on 14/12/2023.
//  Copyright © 2023 Randall Knutson. All rights reserved.
//

import CoreBluetooth
import Foundation

enum EncryptionType: Int {
    case DEFAULT = 0
    case RSv3 = 1
    case BLE_5 = 2
}

class BleComm {
    
    private let okCharCodes: [UInt8] = [0x4f, 0x4b] // O, K
    private let pumpCharCodes: [UInt8] = [0x50, 0x55, 0x4d, 0x50] // P, U, M, P
    private let busyCharCodes: [UInt8] = [0x42, 0x55, 0x53, 0x59] // B, U, S, Y
    
    private let ENCRYPTION_TYPE = EncryptionType.DEFAULT
    
    private let deviceNameRegex = try! NSRegularExpression(pattern: "^[a-zA-Z]{3}[0-9]{5}[a-zA-Z]{2}$") 
    
    private let PACKET_START_BYTE: UInt8 = 0xa5
    private let PACKET_END_BYTE: UInt8 = 0x5a
    private let ENCRYPTED_START_BYTE: UInt8 = 0xaa
    private let ENCRYPTED_END_BYTE: UInt8 = 0xee
    
    private let READ_SERVICE_UUID = CBUUID(string: "FFF0")
    private let READ_CHAR_UUID = CBUUID(string: "FFF1")
    private let WRITE_SERVICE_UUID = CBUUID(string: "FFF0")
    private let WRITE_CHAR_UUID = CBUUID(string: "FFF2")
    
}
