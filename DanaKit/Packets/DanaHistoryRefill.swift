class DanaHistoryRefill: HistoryPacket, DanaKitBasePacket {
    let name = "Review_Refill"
    let opCode = DanaPacketType.OPCODE_REVIEW__REFILL

    func generate() throws -> Data {
        generatePacketHistoryData()
    }

    func parse(data: Data, usingUtc: Bool?) -> any DanaParsePacketProtocol {
        super.parse(data: data, usingUtc: usingUtc)
    }
}
