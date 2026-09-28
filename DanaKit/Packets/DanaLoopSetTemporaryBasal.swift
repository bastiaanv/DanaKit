enum LoopTempBasalDuration: UInt8 {
    case min15 = 150
    case min30 = 160
}

struct PacketLoopSetTemporaryBasal {
    var percent: UInt16
    var duration: LoopTempBasalDuration
}

class DanaLoopSetTemporaryBasal: DanaKitBasePacket {
    let name = "LoopSpecific_SetShortTempBasal"
    let opCode = DanaPacketType.OPCODE_BASAL__APS_SET_TEMPORARY_BASAL

    private let options: PacketLoopSetTemporaryBasal
    init(options: PacketLoopSetTemporaryBasal) {
        self.options = options
    }

    func generate() throws -> Data {
        var percent = options.percent

        if percent > 500 {
            percent = 500
        }

        return Data([
            UInt8(percent & 0xFF),
            UInt8((percent >> 8) & 0xFF),
            options.duration.rawValue
        ])
    }

    func parse(data: Data, usingUtc _: Bool?) -> any DanaParsePacketProtocol {
        DanaParsePacket<String>(success: data[DataStart] == 0, rawData: data, data: nil)
    }
}
