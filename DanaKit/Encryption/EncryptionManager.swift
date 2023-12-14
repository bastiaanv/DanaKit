//
//  EncryptionManager.swift
//  DanaKit
//
//  Created by Bastiaan Verhaar on 14/12/2023.
//  Copyright © 2023 Randall Knutson. All rights reserved.
//

class DanaRSEncryption {
    private static var enhancedEncryption: UInt8 = 0
    private static var isEncryptionMode: Bool = true
    
    // Length 2
    private static var passwordSecret: Data = Data()
    
    // Length: 6
    private static var timeSecret: Data = Data()
    
    // Length: 2
    private static var passKeySecret: Data = Data()
    private static var passKeySecretBackup: Data = Data()
    
    // Length: 6
    private static var pairingKey: Data = Data()
    
    // Length: 3
    private static var randomPairingKey: Data = Data()
    private static var randomSyncKey: UInt8 = 0
    
    // Length: 6
    private static var ble5Key: Data = Data()
    private static var ble5RandomKeys: (UInt8, UInt8, UInt8) = (0, 0, 0)
    
    // Encoding functions -> Encryption in JNI lib
    static func encodePacket(operationCode: UInt8, buffer: Data?, deviceName: String) -> Data {
        let params = EncryptParams(operationCode: operationCode, deviceName: deviceName, enhancedEncryption: self.enhancedEncryption, timeSecret: self.timeSecret, passwordSecret: self.passwordSecret, passKeySecret: self.passKeySecret)
        let result = encrypt(params)
        
        Self.isEncryptionMode = result.isEncryptionMode
        return result.data
    }
    
    static func encodeSecondLevel(data: Data) -> Data {
        var params = EncryptSecondLevelParams(buffer: data, enhancedEncryption: self.enhancedEncryption, pairingKey: self.pairingKey, randomPairingKey: self.randomPairingKey, randomSyncKey: self.randomSyncKey, bleRandomKeys: self.ble5RandomKeys)
        let result = encryptSecondLevel(&params)
        
        Self.randomSyncKey = result.randomSyncKey
        return result.buffer
    }
    
    // Decoding function -> Decrypting in JNI lib
    static func decodePacket(buffer: Data, deviceName: String) -> Data {
        var params = DecryptParam(data: buffer, deviceName: deviceName, enhancedEncryption: self.enhancedEncryption, isEncryptionMode: self.isEncryptionMode, pairingKeyLength: self.pairingKey.count, randomPairingKeyLength: self.randomPairingKey.count, ble5KeyLength: self.ble5Key.count, timeSecret: self.timeSecret, passwordSecret: self.passwordSecret, passKeySecret: self.passKeySecret, passKeySecretBackup: self.passKeySecretBackup)
        
        do {
            let decryptionResult = try decrypt(&params)
            
            Self.isEncryptionMode = decryptionResult.isEncryptionMode
            Self.timeSecret = decryptionResult.timeSecret
            Self.passwordSecret = decryptionResult.passwordSecret
            Self.passKeySecret = decryptionResult.passKeySecret
            Self.passKeySecretBackup = decryptionResult.passKeySecretBackup
            
            return decryptionResult.data
        } catch {
            return Data([])
        }
    }
    
    static func decodeSecondLevel(data: Data) -> Data {
        var params = DecryptSecondLevelParams(buffer: data, enhancedEncryption: Self.enhancedEncryption, pairingKey: self.pairingKey, randomPairingKey: self.randomPairingKey, randomSyncKey: self.randomSyncKey, bleRandomKeys: self.ble5RandomKeys)
        let result = decryptSecondLevel(&params)
        
        Self.randomSyncKey = result.randomSyncKey
        return result.buffer
    }
    
    // Setter functions
    static func setEnhancedEncryption(_ enhancedEncryption: UInt8) {
        Self.enhancedEncryption = enhancedEncryption
    }
    
    static func setPairingKeys(pairingKey: Data, randomPairingKey: Data, randomSyncKey: UInt8) {
        Self.pairingKey = pairingKey
        Self.randomPairingKey = randomPairingKey
        
        if randomSyncKey == 0 {
            Self.randomSyncKey = initialRandomSyncKey(pairingKey: pairingKey)
        } else {
            Self.randomSyncKey = decryptionRandomSyncKey(randomSyncKey: randomSyncKey, randomPairingKey: randomPairingKey)
        }
    }
    
    static func setBle5Key(ble5Key: Data) {
        Self.ble5Key = ble5Key
        
        let i1 = (ble5Key[0] - 0x30) * 10 + (ble5Key[1] - 0x30)
        let i2 = (ble5Key[2] - 0x30) * 10 + (ble5Key[3] - 0x30)
        let i3 = (ble5Key[4] - 0x30) * 10 + (ble5Key[5] - 0x30)
        
        Self.ble5RandomKeys = (
            secondLvlEncryptionLookupShort[Int(i1)],
            secondLvlEncryptionLookupShort[Int(i2)],
            secondLvlEncryptionLookupShort[Int(i3)]
        )
    }
}
