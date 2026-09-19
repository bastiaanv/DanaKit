class DanaHistoryTemporary : HistoryPacket, DanaKitBasePacket {
    let name = "Review_TemporaryBasal"
    let opCode = DanaPacketType.OPCODE_REVIEW__TEMPORARY

    func generate() throws -> Data {
        return generatePacketHistoryData()
    }
    
    func parse(data: Data, usingUtc: Bool?) -> any DanaParsePacketProtocol {
        super.parse(data: data, usingUtc: usingUtc)
    }
}
