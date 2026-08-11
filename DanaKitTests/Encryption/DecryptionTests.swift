@testable import DanaKit
import Testing

struct DecryptionTests {
    @Test func testDecryptMessage() throws {
        var params = DecryptParam(
            data: Data([165, 165, 14, 234, 243, 192, 163, 190, 134, 184, 225, 185, 222, 197, 183, 222, 197, 31, 241, 90, 90]),
            deviceName: DEVICE_NAME,
            enhancedEncryption: 2,
            isEncryptionMode: true,
            pairingKeyLength: 0,
            randomPairingKeyLength: 0,
            ble5KeyLength: 0,
            timeSecret: Data([]),
            passwordSecret: Data([]),
            passKeySecret: Data([]),
            passKeySecretBackup: Data([])
        )

        let decryptionResult = try decrypt(&params)

        #expect(decryptionResult.isEncryptionMode)
        #expect(decryptionResult.passKeySecret == Data([]))
        #expect(decryptionResult.passKeySecretBackup == Data([]))
        #expect(decryptionResult.passwordSecret == Data([]))
        #expect(decryptionResult.timeSecret == Data([]))
        #expect(decryptionResult.data == Data([2, 0, 79, 75, 77, 9, 80, 18, 54, 54, 54, 56, 54, 54]))
    }

    @Test func testThrowIfLengthDoesNotMatch() {
        var params = DecryptParam(
            data: Data([165, 165, 17, 234, 243, 192, 163, 190, 134, 184, 225, 185, 222, 197, 183, 222, 197, 31, 241, 90, 90]),
            deviceName: DEVICE_NAME,
            enhancedEncryption: 2,
            isEncryptionMode: true,
            pairingKeyLength: 0,
            randomPairingKeyLength: 0,
            ble5KeyLength: 0,
            timeSecret: Data([]),
            passwordSecret: Data([]),
            passKeySecret: Data([]),
            passKeySecretBackup: Data([])
        )

        #expect(throws: NSError(domain: "Package length does not match the length attr.", code: 0, userInfo: nil)) {
            try decrypt(&params)
        }
    }

    @Test func testThrowIfCrcFails() {
        var params = DecryptParam(
            data: Data([165, 165, 14, 234, 243, 192, 163, 190, 134, 184, 225, 185, 222, 197, 183, 222, 197, 31, 21, 90, 90]),
            deviceName: DEVICE_NAME,
            enhancedEncryption: 2,
            isEncryptionMode: true,
            pairingKeyLength: 0,
            randomPairingKeyLength: 0,
            ble5KeyLength: 0,
            timeSecret: Data([]),
            passwordSecret: Data([]),
            passKeySecret: Data([]),
            passKeySecretBackup: Data([])
        )

        #expect(throws: NSError(domain: "Crc checksum failed...", code: 0, userInfo: nil)) {
            try decrypt(&params)
        }
    }
}
