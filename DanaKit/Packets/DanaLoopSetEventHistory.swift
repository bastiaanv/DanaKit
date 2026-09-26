enum LoopHistoryEvents {
    static let tempStart: UInt8 = 1
    static let tempStop: UInt8 = 2
    static let extendedStart: UInt8 = 3
    static let extendedStop: UInt8 = 4
    static let bolus: UInt8 = 5
    static let dualBolus: UInt8 = 6
    static let dualExtendedStart: UInt8 = 7
    static let dualExtendedStop: UInt8 = 8
    static let suspendOn: UInt8 = 9
    static let suspendOff: UInt8 = 10
    static let refill: UInt8 = 11
    static let prime: UInt8 = 12
    static let profileChange: UInt8 = 13
    static let carbs: UInt8 = 14
    static let primeCannula: UInt8 = 15
    static let timeChange: UInt8 = 16
}

struct PacketLoopSetEventHistory {
    var packetType: UInt8
    var time: Date
    var param1: UInt16
    var param2: UInt16
}

class DanaLoopSetEventHistory: DanaKitBasePacket {
    let name = "Review_SetApsEvent"
    let opCode = DanaPacketType.OPCODE__APS_SET_EVENT_HISTORY

    private let options: PacketLoopSetEventHistory
    init(options: PacketLoopSetEventHistory) {
        self.options = options
    }

    func generate() throws -> Data {
        var data = Data(count: 11)

        data[0] = options.packetType
        data.addDate(at: 1, date: options.time)

        data[7] = UInt8(options.param1 >> 8)
        data[8] = UInt8(options.param1 & 0xFF)
        data[9] = UInt8(options.param2 >> 8)
        data[10] = UInt8(options.param2 & 0xFF)

        return data
    }

    func parse(data: Data, usingUtc _: Bool?) -> any DanaParsePacketProtocol {
        DanaParsePacket<String>(success: data[DataStart] == 0, rawData: data, data: nil)
    }
}
