@testable import DanaKit
import Testing

class CommonUtilsTests {
    @Test func encodePacketSerialNumber() {
        // Pump check command
        var message = Data([165, 165, 12, 1, 0])
        message += DEVICE_NAME.utf8.map { UInt8($0) }
        message += [188, 122, 90, 90]

        let encodedMessage = DanaKit.encodePacketSerialNumber(buffer: &message, deviceName: DEVICE_NAME)

        #expect(
            encodedMessage == Data([165, 165, 12, 233, 243, 217, 162, 187, 191, 216, 195, 190, 218, 181, 198, 84, 137, 90, 90])
        )
    }

    // TODO: Validate with older Dana pump
    // @Test
    // func encodePacketPassKey() {}

    // TODO: Validate with older Dana pump
    // @Test
    // func encodePacketTime() {}

    // TODO: Validate with older Dana pump
    // @Test
    // func encodePacketPassKeySerialNumber() {}

    // TODO: Validate with older Dana pump
    // @Test
    // func encodePacketPassword() {}

    // TODO: Validate with older Dana pump
    // @Test
    // func initialRandomSyncKey() {}

    // TODO: Validate with older Dana pump
    // @Test
    // func decryptionRandomSyncKey() {}
}
