class DanaBolusCancelExtended : DanaKitBasePacket {
    let name = "Bolus_CancelExtended"
    let opCode = DanaPacketType.OPCODE_BOLUS__SET_EXTENDED_BOLUS_CANCEL

    func generate() -> Data {
        Data()
    }
    
    func parse(data: Data, usingUtc _: Bool?) -> any DanaParsePacketProtocol {
        DanaParsePacket<String>(success: data[DataStart] == 0, rawData: data, data: nil)
    }
}
