class DanaHistoryDaily : HistoryPacket, DanaKitBasePacket {
    let name = "Review_Daily"
    let opCode = DanaPacketType.OPCODE_REVIEW__DAILY

    func generate() throws -> Data {
        return generatePacketHistoryData()
    }
    
    func parse(data: Data, usingUtc: Bool?) -> any DanaParsePacketProtocol {
        super.parse(data: data, usingUtc: usingUtc)
    }
}
