class DanaBasalCancelTemporary : DanaKitBasePacket {
    let name = "Basal_CancelTemporary"
    let opCode = DanaPacketType.OPCODE_BASAL__CANCEL_TEMPORARY_BASAL
    
    func generate() -> Data {
        Data()
    }
    
    func parse(data: Data, usingUtc _: Bool?) -> any DanaParsePacketProtocol {
        DanaParsePacket<String>(success: data[DataStart] == 0, rawData: data, data: nil)
    }
}
