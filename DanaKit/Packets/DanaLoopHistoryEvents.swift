struct PacketLoopHistoryEvents {
    var from: Date?
}

let CommandLoopHistoryEvents: UInt16 = (UInt16(DanaPacketType.TYPE_RESPONSE & 0xFF) << 8) +
    UInt16(DanaPacketType.OPCODE__APS_HISTORY_EVENTS & 0xFF)

func generatePacketLoopHistoryEvents(options: PacketLoopHistoryEvents) -> DanaGeneratePacket {
    var data = Data(count: 6)

    if options.from == nil {
        data[0] = 0
        data[1] = 1
        data[2] = 1
        data[3] = 0
        data[4] = 0
        data[5] = 0
    } else {
        data.addDate(at: 0, date: options.from!)
    }

    return DanaGeneratePacket(
        name: "Review_ApsEvents",
        opCode: DanaPacketType.OPCODE__APS_HISTORY_EVENTS,
        data: data
    )
}

func parsePacketLoopHistoryEvents(data: Data, usingUtc _: Bool?) -> DanaParsePacket<String> {
    // Implement the parse logic as needed
    DanaParsePacket(
        success: data[DataStart] == 0,
        rawData: data,
        data: nil
    )
}
