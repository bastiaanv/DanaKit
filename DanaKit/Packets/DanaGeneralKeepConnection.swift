class DanaGeneralKeepConnection: DanaKitBasePacket {
    let name = "General_KeepConnection"
    let opCode = DanaPacketType.OPCODE_ETC__KEEP_CONNECTION

    func generate() throws -> Data {
        Data()
    }

    func parse(data: Data, usingUtc _: Bool?) -> any DanaParsePacketProtocol {
        DanaParsePacket<String>(success: data[DataStart] == 0, rawData: data, data: nil)
    }
}
