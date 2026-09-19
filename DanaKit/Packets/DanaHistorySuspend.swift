class DanaHistorySuspend : HistoryPacket, DanaKitBasePacket {
    let name = "Review_Suspended"
    let opCode = DanaPacketType.OPCODE_REVIEW__SUSPEND

    func generate() throws -> Data {
        return generatePacketHistoryData()
    }
    
    func parse(data: Data, usingUtc: Bool?) -> any DanaParsePacketProtocol {
        super.parse(data: data, usingUtc: usingUtc)
    }
}
