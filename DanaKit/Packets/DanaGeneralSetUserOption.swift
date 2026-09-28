public struct PacketGeneralSetUserOption {
    let isTimeDisplay24H: Bool
    let isButtonScrollOnOff: Bool
    let beepAndAlarm: UInt8
    let lcdOnTimeInSec: UInt8
    let backlightOnTimeInSec: UInt8
    let selectedLanguage: UInt8
    let units: UInt8
    let shutdownHour: UInt8
    let lowReservoirRate: UInt8
    let cannulaVolume: UInt16
    let refillAmount: UInt16

    /** Only on hw v7+ */
    let targetBg: UInt16?
}

class DanaGeneralSetUserOption: DanaKitBasePacket {
    let name = "General_SetUserOption"
    let opCode = DanaPacketType.OPCODE_OPTION__SET_USER_OPTION

    private let options: PacketGeneralSetUserOption
    init(options: PacketGeneralSetUserOption) {
        self.options = options
    }

    func generate() throws -> Data {
        var data = Data(count: options.targetBg != nil ? 15 : 13)
        data[0] = options.isTimeDisplay24H ? 0x00 : 0x01
        data[1] = options.isButtonScrollOnOff ? 0x01 : 0x00
        data[2] = options.beepAndAlarm
        data[3] = options.lcdOnTimeInSec
        data[4] = options.backlightOnTimeInSec
        data[5] = options.selectedLanguage
        data[6] = options.units
        data[7] = options.shutdownHour
        data[8] = options.lowReservoirRate
        data[9] = UInt8(options.cannulaVolume & 0xFF)
        data[10] = UInt8((options.cannulaVolume >> 8) & 0xFF)
        data[11] = UInt8(options.refillAmount & 0xFF)
        data[12] = UInt8((options.refillAmount >> 8) & 0xFF)

        if let targetBg = options.targetBg {
            data[13] = UInt8(targetBg & 0xFF)
            data[14] = UInt8((targetBg >> 8) & 0xFF)
        }

        return data
    }

    func parse(data: Data, usingUtc _: Bool?) -> any DanaParsePacketProtocol {
        DanaParsePacket<String>(success: data[DataStart] == 0, rawData: data, data: nil)
    }
}
