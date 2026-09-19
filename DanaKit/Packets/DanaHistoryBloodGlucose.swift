class DanaHistoryBloodGlucose : HistoryPacket, DanaKitBasePacket {
    let name = "Review_BloodGlucose"
    let opCode = DanaPacketType.OPCODE_REVIEW__BLOOD_GLUCOSE

    func generate() throws -> Data {
        return generatePacketHistoryData()
    }
    
    func parse(data: Data, usingUtc: Bool?) -> any DanaParsePacketProtocol {
        super.parse(data: data, usingUtc: usingUtc)
    }
}
