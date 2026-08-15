enum LoopTempBasalDuration: UInt8 {
    case min15 = 150
    case min30 = 160
}

struct PacketLoopSetTemporaryBasal {
    var percent: UInt16
    var duration: LoopTempBasalDuration
}

let CommandLoopSetTemporaryBasal: UInt16 = (UInt16(DanaPacketType.TYPE_RESPONSE & 0xFF) << 8) +
    UInt16(DanaPacketType.OPCODE_BASAL__APS_SET_TEMPORARY_BASAL & 0xFF)

func generatePacketLoopSetTemporaryBasal(options: PacketLoopSetTemporaryBasal) -> DanaGeneratePacket {
    var percent = options.percent

    if percent > 500 {
        percent = 500
    }

    let data = Data([
        UInt8(percent & 0xFF),
        UInt8((percent >> 8) & 0xFF),
        options.duration.rawValue
    ])

    return DanaGeneratePacket(
        name: "LoopSpecific_SetShortTempBasal",
        opCode: DanaPacketType.OPCODE_BASAL__APS_SET_TEMPORARY_BASAL,
        data: data
    )
}

func parsePacketLoopSetTemporaryBasal(data: Data, usingUtc _: Bool?) -> DanaParsePacket<String> {
    DanaParsePacket(
        success: data[DataStart] == 0,
        rawData: data,
        data: nil
    )
}
