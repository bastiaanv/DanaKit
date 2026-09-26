class DanaGeneralClearUserTimeChangeFlag: DanaKitBasePacket {
    let name = "General_ClearUserTimeChangeFlag"
    let opCode = DanaPacketType.OPCODE_REVIEW__SET_USER_TIME_CHANGE_FLAG_CLEAR

    func generate() throws -> Data {
        Data()
    }

    func parse(data: Data, usingUtc _: Bool?) -> any DanaParsePacketProtocol {
        DanaParsePacket<String>(success: data[DataStart] == 0, rawData: data, data: nil)
    }
}
