class DanaHistoryBolus: HistoryPacket, DanaKitBasePacket {
    let name = "Review_Bolus"
    let opCode = DanaPacketType.OPCODE_REVIEW__BOLUS

    func generate() throws -> Data {
        generatePacketHistoryData()
    }

    func parse(data: Data, usingUtc: Bool?) -> any DanaParsePacketProtocol {
        super.parse(data: data, usingUtc: usingUtc)
    }
}
