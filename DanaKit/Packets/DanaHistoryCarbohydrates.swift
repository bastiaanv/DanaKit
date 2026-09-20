class DanaHistoryCarbohydrates: HistoryPacket, DanaKitBasePacket {
    let name = "Review_Carbohydrates"
    let opCode = DanaPacketType.OPCODE_REVIEW__CARBOHYDRATE

    func generate() throws -> Data {
        generatePacketHistoryData()
    }

    func parse(data: Data, usingUtc: Bool?) -> any DanaParsePacketProtocol {
        super.parse(data: data, usingUtc: usingUtc)
    }
}
