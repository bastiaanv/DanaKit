public enum BeepAlarmType: UInt8, Codable {
    case sound = 1
    case vibration = 2
    case both = 3

    static func all() -> [Int] {
        [1, 2, 3]
    }

    var title: String {
        switch self {
        case .sound:
            return String(localized: "Sound", comment: "beepAndAlarm.sound")
        case .vibration:
            return String(localized: "Vibration", comment: "beepAndAlarm.vibration")
        case .both:
            return String(localized: "Both", comment: "beepAndAlarm.both")
        }
    }
}

public struct PacketGeneralGetUserOption: Codable {
    var isTimeDisplay24H: Bool
    var isButtonScrollOnOff: Bool
    var beepAndAlarm: BeepAlarmType
    var lcdOnTimeInSec: UInt8
    var backlightOnTimInSec: UInt8
    var selectedLanguage: UInt8
    var units: UInt8
    var shutdownHour: UInt8
    var lowReservoirRate: UInt8
    var cannulaVolume: UInt16
    var refillAmount: UInt16

    var selectableLanguage1: UInt8
    var selectableLanguage2: UInt8
    var selectableLanguage3: UInt8
    var selectableLanguage4: UInt8
    var selectableLanguage5: UInt8

    /** Only on hw v7+ */
    var targetBg: UInt16?
}

class DanaGeneralGetUserOption: DanaKitBasePacket {
    let name = "General_GetUserOption"
    let opCode = DanaPacketType.OPCODE_OPTION__GET_USER_OPTION

    func generate() throws -> Data {
        Data()
    }

    func parse(data: Data, usingUtc _: Bool?) -> any DanaParsePacketProtocol {
        guard data.count > 19 else {
            return DanaParsePacket<String>(success: false, rawData: data, data: nil)
        }

        return DanaParsePacket(
            success: data[DataStart + 3] >= 5,
            rawData: data,
            data: PacketGeneralGetUserOption(
                isTimeDisplay24H: data[DataStart] == 0,
                isButtonScrollOnOff: data[DataStart + 1] == 1,
                beepAndAlarm: BeepAlarmType(rawValue: data[DataStart + 2]) ?? .sound,
                lcdOnTimeInSec: data[DataStart + 3],
                backlightOnTimInSec: data[DataStart + 4],
                selectedLanguage: data[DataStart + 5],
                units: data[DataStart + 6],
                shutdownHour: data[DataStart + 7],
                lowReservoirRate: data[DataStart + 8],
                cannulaVolume: data.uint16(at: DataStart + 9),
                refillAmount: data.uint16(at: DataStart + 11),
                selectableLanguage1: data[DataStart + 13],
                selectableLanguage2: data[DataStart + 14],
                selectableLanguage3: data[DataStart + 15],
                selectableLanguage4: data[DataStart + 16],
                selectableLanguage5: data[DataStart + 17],
                targetBg: data.count >= 22 ? data.uint16(at: DataStart + 18) : nil
            )
        )
    }
}
