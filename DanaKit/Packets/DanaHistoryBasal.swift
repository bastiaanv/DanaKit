class DanaHistoryBasal: HistoryPacket, DanaKitBasePacket {
    let name = "Review_Basal"
    let opCode = DanaPacketType.OPCODE_REVIEW__BASAL

    func generate() throws -> Data {
        generatePacketHistoryData()
    }

    func parse(data: Data, usingUtc: Bool?) -> any DanaParsePacketProtocol {
        super.parse(data: data, usingUtc: usingUtc)
    }
}
