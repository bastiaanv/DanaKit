class DanaKitEncryption {
    private var enhancedEncryption: UInt8 = 0
    private var isEncryptionMode: Bool = true

    // Length 2
    private var passwordSecret = Data()

    // Length: 6
    private var timeSecret = Data()

    // Length: 2
    private var passKeySecret = Data()
    private var passKeySecretBackup = Data()

    // Length: 6
    private var pairingKey = Data()

    // Length: 3
    private var randomPairingKey = Data()
    private var randomSyncKey: UInt8 = 0

    // Length: 6
    private var ble5Key = Data()
    private var ble5RandomKeys: (UInt8, UInt8, UInt8) = (0, 0, 0)
    
    /**
     * Second level encryption lookup table. Used in:
     * `info_nightscout_androidaps_danars_encryption_BleEncryption_encryptSecondLevelPacketJni` &
     * `info_nightscout_androidaps_danars_encryption_BleEncryption_decryptSecondLevelPacketJni`
     */
    let secondLvlEncryptionLookup: [UInt8] = [
        0x63, 0x7C, 0x77, 0x7B, 0xF2, 0x6B, 0x6F, 0xC5, 0x30, 0x01, 0x67, 0x2B, 0xFE, 0xD7, 0xAB, 0x76, 0xCA, 0x82, 0xC9, 0x7D, 0xFA,
        0x59, 0x47, 0xF0, 0xAD, 0xD4,
        0xA2, 0xAF, 0x9C, 0xA4, 0x72, 0xC0, 0xB7, 0xFD, 0x93, 0x26, 0x36, 0x3F, 0xF7, 0xCC, 0x34, 0xA5, 0xE5, 0xF1, 0x71, 0xD8, 0x31,
        0x15, 0x04, 0xC7, 0x23, 0xC3,
        0x18, 0x96, 0x05, 0x9A, 0x07, 0x12, 0x80, 0xE2, 0xEB, 0x27, 0xB2, 0x75, 0x09, 0x83, 0x2C, 0x1A, 0x1B, 0x6E, 0x5A, 0xA0, 0x52,
        0x3B, 0xD6, 0xB3, 0x29, 0xE3,
        0x2F, 0x84, 0x53, 0xD1, 0x00, 0xED, 0x20, 0xFC, 0xB1, 0x5B, 0x6A, 0xCB, 0xBE, 0x39, 0x4A, 0x4C, 0x58, 0xCF, 0xD0, 0xEF, 0xAA,
        0xFB, 0x43, 0x4D, 0x33, 0x85,
        0x45, 0xF9, 0x02, 0x7F, 0x50, 0x3C, 0x9F, 0xA8, 0x51, 0xA3, 0x40, 0x8F, 0x92, 0x9D, 0x38, 0xF5, 0xBC, 0xB6, 0xDA, 0x21, 0x10,
        0xFF, 0xF3, 0xD2, 0xCD, 0x0C,
        0x13, 0xEC, 0x5F, 0x97, 0x44, 0x17, 0xC4, 0xA7, 0x7E, 0x3D, 0x64, 0x5D, 0x19, 0x73, 0x60, 0x81, 0x4F, 0xDC, 0x22, 0x2A, 0x90,
        0x88, 0x46, 0xEE, 0xB8, 0x14,
        0xDE, 0x5E, 0x0B, 0xDB, 0xE0, 0x32, 0x3A, 0x0A, 0x49, 0x06, 0x24, 0x5C, 0xC2, 0xD3, 0xAC, 0x62, 0x91, 0x95, 0xE4, 0x79, 0xE7,
        0xC8, 0x37, 0x6D, 0x8D, 0xD5,
        0x4E, 0xA9, 0x6C, 0x56, 0xF4, 0xEA, 0x65, 0x7A, 0xAE, 0x08, 0xBA, 0x78, 0x25, 0x2E, 0x1C, 0xA6, 0xB4, 0xC6, 0xE8, 0xDD, 0x74,
        0x1F, 0x4B, 0xBD, 0x8B, 0x8A,
        0x70, 0x3E, 0xB5, 0x66, 0x48, 0x03, 0xF6, 0x0E, 0x61, 0x35, 0x57, 0xB9, 0x86, 0xC1, 0x1D, 0x9E, 0xE1, 0xF8, 0x98, 0x11, 0x69,
        0xD9, 0x8E, 0x94, 0x9B, 0x1E,
        0x87, 0xE9, 0xCE, 0x55, 0x28, 0xDF, 0x8C, 0xA1, 0x89, 0x0D, 0xBF, 0xE6, 0x42, 0x68, 0x41, 0x99, 0x2D, 0x0F, 0xB0, 0x54, 0xBB,
        0x16
    ]
    
    /**
     * A shorter second level encryption lookup table. Used in:
     * `info_nightscout_androidaps_danars_encryption_BleEncryption_setBle5KeyJni`
     */
    let secondLvlEncryptionLookupShort: [UInt8] = [
        0x63, 0x7C, 0x77, 0x7B, 0xF2, 0x6B, 0x6F, 0xC5, 0x30, 0x01, 0x67, 0x2B, 0xFE, 0xD7, 0xAB, 0x76, 0x6C, 0x70, 0x48, 0x50, 0xFD,
        0xED, 0xB9, 0xDA, 0x5E, 0x15,
        0x46, 0x57, 0xA7, 0x8D, 0x9D, 0x84, 0xB7, 0xFD, 0x93, 0x26, 0x36, 0x3F, 0xF7, 0xCC, 0x34, 0xA5, 0xE5, 0xF1, 0x71, 0xD8, 0x31,
        0x15, 0x47, 0xF1, 0x1A, 0x71,
        0x1D, 0x29, 0xC5, 0x89, 0x6F, 0xB7, 0x62, 0x0E, 0xAA, 0x18, 0xBE, 0x1B, 0x09, 0x83, 0x2C, 0x1A, 0x1B, 0x6E, 0x5A, 0xA0, 0x52,
        0x3B, 0xD6, 0xB3, 0x29, 0xE3,
        0x2F, 0x84, 0x53, 0xD1, 0xA0, 0xED, 0x20, 0xFC, 0xB1, 0x5B, 0x6A, 0xCB, 0xBE, 0x39, 0x4A, 0x4C, 0x58, 0xCF, 0xB0, 0x54, 0xBB,
        0x16
    ]
    
    func isDanaI() -> Bool {
        return enhancedEncryption == EncryptionType.BLE_5.rawValue
    }
    
    func isDanaRS() -> Bool {
        return enhancedEncryption == EncryptionType.RSv3.rawValue
    }
    
    func shouldDoSecondLevel() -> Bool {
        return enhancedEncryption != EncryptionType.DEFAULT.rawValue
    }

    // Encoding functions -> Encryption in JNI lib
    func encodePacket(operationCode: UInt8, buffer: Data?, deviceName: String) -> Data {
        let params = EncryptParams(
            operationCode: operationCode,
            data: buffer,
            deviceName: deviceName,
            enhancedEncryption: enhancedEncryption,
            timeSecret: timeSecret,
            passwordSecret: passwordSecret,
            passKeySecret: passKeySecret
        )
        let result = encrypt(params)

        isEncryptionMode = result.isEncryptionMode
        return result.data
    }

    func encodeSecondLevel(data: Data) -> Data {
        var params = EncryptSecondLevelParams(
            buffer: data,
            enhancedEncryption: enhancedEncryption,
            pairingKey: pairingKey,
            randomPairingKey: randomPairingKey,
            randomSyncKey: randomSyncKey,
            bleRandomKeys: ble5RandomKeys
        )
        let result = encryptSecondLevel(&params)

        randomSyncKey = result.randomSyncKey
        return result.buffer
    }

    // Decoding function -> Decrypting in JNI lib
    func decodePacket(buffer: Data, deviceName: String) -> Data {
        var params = DecryptParam(
            data: buffer,
            deviceName: deviceName,
            enhancedEncryption: enhancedEncryption,
            isEncryptionMode: isEncryptionMode,
            pairingKeyLength: pairingKey.count,
            randomPairingKeyLength: randomPairingKey.count,
            ble5KeyLength: ble5Key.count,
            timeSecret: timeSecret,
            passwordSecret: passwordSecret,
            passKeySecret: passKeySecret,
            passKeySecretBackup: passKeySecretBackup
        )

        do {
            let decryptionResult = try decrypt(&params)

            isEncryptionMode = decryptionResult.isEncryptionMode
            timeSecret = decryptionResult.timeSecret
            passwordSecret = decryptionResult.passwordSecret
            passKeySecret = decryptionResult.passKeySecret
            passKeySecretBackup = decryptionResult.passKeySecretBackup

            return decryptionResult.data
        } catch {
            return Data([])
        }
    }

    func decodeSecondLevel(data: Data) -> Data {
        var params = DecryptSecondLevelParams(
            buffer: data,
            enhancedEncryption: enhancedEncryption,
            pairingKey: pairingKey,
            randomPairingKey: randomPairingKey,
            randomSyncKey: randomSyncKey,
            bleRandomKeys: ble5RandomKeys
        )
        let result = decryptSecondLevel(&params)

        randomSyncKey = result.randomSyncKey
        return result.buffer
    }

    // Setter functions
    func setEnhancedEncryption(_ enhancedEncryption: UInt8) {
        self.enhancedEncryption = enhancedEncryption
    }

    func setPairingKeys(pairingKey: Data, randomPairingKey: Data, randomSyncKey: UInt8?) {
        self.pairingKey = pairingKey
        self.randomPairingKey = randomPairingKey

        if let randomSyncKey = randomSyncKey {
            self.randomSyncKey = decryptionRandomSyncKey(randomSyncKey: randomSyncKey, randomPairingKey: randomPairingKey)
        } else {
            self.randomSyncKey = initialRandomSyncKey(pairingKey: pairingKey)
        }
    }

    func getPairingKeys() -> (Data, Data) {
        return (pairingKey, randomPairingKey)
    }

    func setBle5Key(ble5Key: Data) {
        self.ble5Key = ble5Key

        let i1 = Int((ble5Key[0] - 0x30) * 10) &+ Int(ble5Key[1] - 0x30)
        let i2 = Int((ble5Key[2] - 0x30) * 10) &+ Int(ble5Key[3] - 0x30)
        let i3 = Int((ble5Key[4] - 0x30) * 10) &+ Int(ble5Key[5] - 0x30)

        ble5RandomKeys = (
            secondLvlEncryptionLookupShort[Int(i1)],
            secondLvlEncryptionLookupShort[Int(i2)],
            secondLvlEncryptionLookupShort[Int(i3)]
        )
    }
}
