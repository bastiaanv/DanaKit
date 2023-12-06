//
//  Encrypt.swift
//  DanaKit
//
//  Created by Bastiaan Verhaar on 06/12/2023.
//  Copyright © 2023 Randall Knutson. All rights reserved.
//

let timeInformationEnhancedEncryption2Lookup: [UInt8] = [
    0,
    0x17 ^ 0x1a,
    0xd1 ^ 0xc0,
    0xaf ^ 0xa9
]

struct EncryptParams {
    var operationCode: UInt8
    var data: Data?
    var deviceName: String
    var enhancedEncryption: UInt8
    var timeSecret: Data
    var passwordSecret: Data
    var passKeySecret: Data
}

func encrypt(_ options: EncryptParams) -> (data: Data, isEncryptionMode: Bool) {
    switch options.operationCode {
    // DANAR_PACKET__OPCODE_ENCRYPTION__PUMP_CHECK
    case 0x00:
        return encodePumpCheckCommand(deviceName: options.deviceName, enhancedEncryption: options.enhancedEncryption)

    // DANAR_PACKET__OPCODE_ENCRYPTION__TIME_INFORMATION
    case 0x01:
        return encodeTimeInformation(data: options.data, deviceName: options.deviceName, enhancedEncryption: options.enhancedEncryption)

    // DANAR_PACKET__OPCODE_ENCRYPTION__CHECK_PASSKEY
    case 0xd0:
        return encodeCheckPassKeyCommand(data: options.data, deviceName: options.deviceName, enhancedEncryption: options.enhancedEncryption)

    // DANAR_PACKET__OPCODE_ENCRYPTION__PASSKEY_REQUEST
    case 0xd1:
        return encodeRequestCommand(operationCode: options.operationCode, deviceName: options.deviceName, enhancedEncryption: options.enhancedEncryption)
        
        // DANAR_PACKET__OPCODE_ENCRYPTION__GET_PUMP_CHECK
    case 0xf3:
        return encodeRequestCommand(operationCode: options.operationCode, deviceName: options.deviceName, enhancedEncryption: options.enhancedEncryption)
        
        // DANAR_PACKET__OPCODE_ENCRYPTION__GET_EASYMENU_CHECK
    case 0xf4:
        return encodeRequestCommand(operationCode: options.operationCode, deviceName: options.deviceName, enhancedEncryption: options.enhancedEncryption)

    default:
        return encodeDefault(options: options)
    }
}

func encryptSecondLevel(
    buffer: inout Data,
    enhancedEncryption: UInt8,
    pairingKey: Data,
    randomPairingKey: Data,
    randomSyncKey: UInt8,
    bleRandomKeys: (UInt8, UInt8, UInt8)
) -> (randomSyncKey: UInt8, buffer: Data) {
    
    var updatedRandomSyncKey = randomSyncKey

    if enhancedEncryption == 1 {
        if buffer[0] == 0xa5 && buffer[1] == 0xa5 {
            buffer[0] = 0x7a
            buffer[1] = 0x7a
        }

        if buffer[buffer.count - 2] == 0x5a && buffer[buffer.count - 1] == 0x5a {
            buffer[buffer.count - 2] = 0x2e
            buffer[buffer.count - 1] = 0x2e
        }

        for i in 0..<buffer.count {
            buffer[i] ^= pairingKey[0]
            buffer[i] &-= updatedRandomSyncKey
            buffer[i] = ((buffer[i] >> 4) & 0xf) | (((buffer[i] & 0xf) << 4) & 0xff)

            buffer[i] &+= pairingKey[1]
            buffer[i] ^= pairingKey[2]
            buffer[i] = ((buffer[i] >> 4) & 0xf) | (((buffer[i] & 0xf) << 4) & 0xff)

            buffer[i] &-= pairingKey[3]
            buffer[i] ^= pairingKey[4]
            buffer[i] = ((buffer[i] >> 4) & 0xf) | (((buffer[i] & 0xf) << 4) & 0xff)

            buffer[i] ^= pairingKey[5]
            buffer[i] ^= updatedRandomSyncKey
            buffer[i] ^= secondLvlEncryptionLookup[Int(pairingKey[0])] // You need to define secondLvlEncryptionLookup
            buffer[i] &+= secondLvlEncryptionLookup[Int(pairingKey[1])]
            buffer[i] &-= secondLvlEncryptionLookup[Int(pairingKey[2])]
            buffer[i] = ((buffer[i] >> 4) & 0xf) | (((buffer[i] & 0xf) << 4) & 0xff)

            buffer[i] ^= secondLvlEncryptionLookup[Int(pairingKey[3])]
            buffer[i] &+= secondLvlEncryptionLookup[Int(pairingKey[4])]
            buffer[i] &-= secondLvlEncryptionLookup[Int(pairingKey[5])]
            buffer[i] ^= secondLvlEncryptionLookup[Int(randomPairingKey[0])]
            buffer[i] &+= secondLvlEncryptionLookup[Int(randomPairingKey[1])]
            buffer[i] &-= secondLvlEncryptionLookup[Int(randomPairingKey[2])]

            updatedRandomSyncKey = buffer[i]
        }
    } else if enhancedEncryption == 2 {
        if buffer[0] == 0xa5 && buffer[1] == 0xa5 {
            buffer[0] = 0xaa
            buffer[1] = 0xaa
        }

        if buffer[buffer.count - 2] == 0x5a && buffer[buffer.count - 1] == 0x5a {
            buffer[buffer.count - 2] = 0xee
            buffer[buffer.count - 1] = 0xee
        }

        for i in 0..<buffer.count {
            buffer[i] &+= bleRandomKeys.0
            buffer[i] = ((buffer[i] >> 4) & 0x0f) | (((buffer[i] & 0x0f) << 4) & 0xf0)

            buffer[i] &-= bleRandomKeys.1
            buffer[i] ^= bleRandomKeys.2
        }
    }

    return (updatedRandomSyncKey, buffer)
}

func encodePumpCheckCommand(deviceName: String, enhancedEncryption: UInt8) -> (data: Data, isEncryptionMode: Bool) {
    var buffer = Data(count: 19)
    buffer[0] = 0xa5 // header 1
    buffer[1] = 0xa5 // header 2
    buffer[2] = 0x0c // length
    buffer[3] = DanaPacketType.TYPE_ENCRYPTION_REQUEST
    buffer[4] = 0x00 // pump_check command

    // Device name
    let deviceNameBytes = Array(deviceName.utf8.prefix(10))
    buffer.replaceSubrange(5..<15, with: deviceNameBytes)

    let crc = generateCrc(buffer: buffer[3..<15], enhancedEncryption: enhancedEncryption, isEncryptionCommand: true)
    buffer[15] = UInt8((crc >> 8) & 0xff) // crc 1
    buffer[16] = UInt8(crc & 0xff) // crc 2

    buffer[17] = 0x5a // footer 1
    buffer[18] = 0x5a // footer 2

    let encodedData = encodePacketSerialNumber(buffer: &buffer, deviceName: deviceName)
    
    return (data: encodedData, isEncryptionMode: true)
}

func encodeRequestCommand(operationCode: UInt8, deviceName: String, enhancedEncryption: UInt8) -> (data: Data, isEncryptionMode: Bool) {
    var buffer = Data(count: 9)
    buffer[0] = 0xa5 // header 1
    buffer[1] = 0xa5 // header 2
    buffer[2] = 0x02 // length
    buffer[3] = DanaPacketType.TYPE_ENCRYPTION_REQUEST
    buffer[4] = operationCode

    let crc = generateCrc(buffer: buffer.subdata(in: 3..<5), enhancedEncryption: enhancedEncryption, isEncryptionCommand: true)
    buffer[5] = UInt8((crc >> 8) & 0xff) // crc 1
    buffer[6] = UInt8(crc & 0xff) // crc 2
    buffer[7] = 0x5a // footer 1
    buffer[8] = 0x5a // footer 2

    let encodedData = encodePacketSerialNumber(buffer: &buffer, deviceName: deviceName)
    
    return (data: encodedData, isEncryptionMode: true)
}

func encodeTimeInformation(data: Data?, deviceName: String, enhancedEncryption: UInt8) -> (data: Data, isEncryptionMode: Bool) {
    let lengthOfData = data?.count ?? 0
    var buffer = Data(count: 9 + lengthOfData)
    buffer[0] = 0xa5 // header 1
    buffer[1] = 0xa5 // header 2
    buffer[2] = UInt8(0x02 + lengthOfData) // length
    buffer[3] = DanaPacketType.TYPE_ENCRYPTION_REQUEST
    buffer[4] = 0x01 // time information command

    if let data = data, data.count > 0 {
        // TODO: Need to find a cleaner way to solve the constant issue
        /* Original code:
         if (enhancedEncryption === 2) {
               data[1] = 0x17 ^ 0x1a;
               data[2] = 0xd1 ^ 0xc0;
               data[3] = 0xaf ^ 0xa9;
             }
         */
        
        for i in 0..<data.count {
            if enhancedEncryption == 2 && i > 0 && i < 4 {
                buffer[5 + i] = timeInformationEnhancedEncryption2Lookup[i]
            } else {
                buffer[5 + i] = data[i]
            }
        }
    }

    let crc = generateCrc(buffer: buffer.subdata(in: 3..<(5 + lengthOfData)), enhancedEncryption: enhancedEncryption, isEncryptionCommand: true)
    buffer[5 + lengthOfData] = UInt8((crc >> 8) & 0xff) // crc 1
    buffer[6 + lengthOfData] = UInt8(crc & 0xff) // crc 2
    buffer[7 + lengthOfData] = 0x5a // footer 1
    buffer[8 + lengthOfData] = 0x5a // footer 2

    let encodedData = encodePacketSerialNumber(buffer: &buffer, deviceName: deviceName)
    
    return (data: encodedData, isEncryptionMode: true)
}

func encodeCheckPassKeyCommand(data: Data?, deviceName: String, enhancedEncryption: UInt8) -> (data: Data, isEncryptionMode: Bool) {
    let lengthOfData = data?.count ?? 0
    var buffer = Data(count: 9 + lengthOfData)
    buffer[0] = 0xa5 // header 1
    buffer[1] = 0xa5 // header 2
    buffer[2] = UInt8(0x02 + lengthOfData) // length
    buffer[3] = DanaPacketType.TYPE_ENCRYPTION_REQUEST
    buffer[4] = 0xd0 // check passkey command

    if let data = data, data.count > 0 {
        for i in 0..<data.count {
            buffer[5 + i] = encodePacketPassKeySerialNumber(value: data[i], deviceName: deviceName)
        }
    }

    let crc = generateCrc(buffer: buffer.subdata(in: 3..<(5 + lengthOfData)), enhancedEncryption: enhancedEncryption, isEncryptionCommand: true)
    buffer[5 + lengthOfData] = UInt8((crc >> 8) & 0xff) // crc 1
    buffer[6 + lengthOfData] = UInt8(crc & 0xff) // crc 2
    buffer[7 + lengthOfData] = 0x5a // footer 1
    buffer[8 + lengthOfData] = 0x5a // footer 2

    let encodedData = encodePacketSerialNumber(buffer: &buffer, deviceName: deviceName)
    return (data: encodedData, isEncryptionMode: true)
}

func encodeDefault(options: EncryptParams) -> (data: Data, isEncryptionMode: Bool) {
    let lengthOfData = options.data?.count ?? 0
    var buffer = Data(count: 9 + lengthOfData)
    buffer[0] = 0xa5 // header 1
    buffer[1] = 0xa5 // header 2
    buffer[2] = UInt8(0x02 + lengthOfData) // length
    buffer[3] = DanaPacketType.TYPE_COMMAND
    buffer[4] = options.operationCode // operation code

    if let data = options.data, lengthOfData > 0 {
        for i in 0..<lengthOfData {
            buffer[5 + i] = data[i]
        }
    }

    let crc = generateCrc(buffer: buffer.subdata(in: 3..<(5 + lengthOfData)), enhancedEncryption: options.enhancedEncryption, isEncryptionCommand: false)
    buffer[5 + lengthOfData] = UInt8((crc >> 8) & 0xff) // crc 1
    buffer[6 + lengthOfData] = UInt8(crc & 0xff) // crc 2
    buffer[7 + lengthOfData] = 0x5a // footer 1
    buffer[8 + lengthOfData] = 0x5a // footer 2

    var encrypted1 = encodePacketSerialNumber(buffer: &buffer, deviceName: options.deviceName)
    if options.enhancedEncryption == 0 {
        encrypted1 = encodePacketTime(buffer: &encrypted1, timeSecret: options.timeSecret)
        encrypted1 = encodePacketPassword(buffer: &encrypted1, passwordSecret: options.passwordSecret)
        encrypted1 = encodePacketPassKey(buffer: &encrypted1, passkeySecret: options.passKeySecret)
    }

    return (data: encrypted1, isEncryptionMode: false)
}
