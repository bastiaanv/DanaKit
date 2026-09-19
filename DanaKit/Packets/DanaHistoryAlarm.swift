class DanaHistoryAlarm : HistoryPacket, DanaKitBasePacket {
    let name = "Review_Alarm"
    let opCode = DanaPacketType.OPCODE_REVIEW__ALARM

    func generate() throws -> Data {
        return generatePacketHistoryData()
    }
    
    func parse(data: Data, usingUtc: Bool?) -> any DanaParsePacketProtocol {
        super.parse(data: data, usingUtc: usingUtc)
    }
}
