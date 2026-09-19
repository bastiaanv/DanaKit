struct PacketLoopHistoryEvents {
    var from: Date?
}

class DanaLoopHistoryEvents : HistoryPacket, DanaKitBasePacket {
    let name = "Review_ApsEvents"
    let opCode = DanaPacketType.OPCODE__APS_HISTORY_EVENTS

    func generate() throws -> Data {
        return generatePacketHistoryData()
    }
    
    func parse(data: Data, usingUtc: Bool?) -> any DanaParsePacketProtocol {
        super.parse(data: data, usingUtc: usingUtc)
    }
}
