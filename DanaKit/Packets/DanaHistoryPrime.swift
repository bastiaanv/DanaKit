class DanaHistoryPrime : HistoryPacket, DanaKitBasePacket {
    let name = "Review_Prime"
    let opCode = DanaPacketType.OPCODE_REVIEW__PRIME

    func generate() throws -> Data {
        return generatePacketHistoryData()
    }
    
    func parse(data: Data, usingUtc: Bool?) -> any DanaParsePacketProtocol {
        super.parse(data: data, usingUtc: usingUtc)
    }
}
