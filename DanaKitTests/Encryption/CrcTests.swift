import Testing
@testable import DanaKit

struct CRCTests {
    
    @Test
    func testGenerateCrcEnhancedEncryption0IsEncryptionCommandTrue() async throws {
        // pump_check command
        let data: [UInt8] = [1, 0] + Array(DEVICE_NAME.utf8)
        let crc = generateCrc(buffer: Data(data), enhancedEncryption: 0, isEncryptionCommand: true)
        
        #expect(crc == 0xBC7A)
    }
    
    @Test
    func testGenerateCrcEnhancedEncryption1IsEncryptionCommandFalse() async throws {
        // BasalSetTemporary command (200%, 1 hour)
        let data: [UInt8] = [161, 96, 200, 1]
        let crc = generateCrc(buffer: Data(data), enhancedEncryption: 1, isEncryptionCommand: false)
        
        #expect(crc == 0x33FD)
    }
    
    @Test
    func testGenerateCrcEnhancedEncryption1IsEncryptionCommandTrue() async throws {
        // TIME_INFORMATION command -> sendTimeInfo
        let data: [UInt8] = [1, 1]
        let crc = generateCrc(buffer: Data(data), enhancedEncryption: 1, isEncryptionCommand: true)
        
        #expect(crc == 0x0990)
    }
    
    @Test
    func testGenerateCrcEnhancedEncryption2IsEncryptionCommandFalse() async throws {
        // BasalSetTemporary command (200%, 1 hour)
        let data: [UInt8] = [161, 96, 200, 1]
        let crc = generateCrc(buffer: Data(data), enhancedEncryption: 2, isEncryptionCommand: false)
        
        #expect(crc == 0x7A1A)
    }
    
    @Test
    func testGenerateCrcEnhancedEncryption2IsEncryptionCommandTrue() async throws {
        // TIME_INFORMATION command -> sendBLE5PairingInformation
        let data: [UInt8] = [1, 1, 0, 0, 0, 0]
        let crc = generateCrc(buffer: Data(data), enhancedEncryption: 2, isEncryptionCommand: true)
        
        #expect(crc == 0x1FEF)
    }
}
