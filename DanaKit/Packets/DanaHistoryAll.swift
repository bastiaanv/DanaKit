class DanaHistoryAll : HistoryPacket, DanaKitBasePacket {
    let name = "Review_AllHistory"
    let opCode = DanaPacketType.OPCODE_REVIEW__ALL_HISTORY

    func generate() throws -> Data {
        return generatePacketHistoryData()
    }
    
    func parse(data: Data, usingUtc: Bool?) -> any DanaParsePacketProtocol {
        super.parse(data: data, usingUtc: usingUtc)
    }
}
