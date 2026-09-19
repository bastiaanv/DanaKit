class DanaBolusStop : DanaKitBasePacket {
    let name = "Bolus_Stop"
    let opCode = DanaPacketType.OPCODE_BOLUS__SET_STEP_BOLUS_STOP

    func generate() throws -> Data {
        Data()
    }
    
    func parse(data: Data, usingUtc _: Bool?) -> any DanaParsePacketProtocol {
        DanaParsePacket<String>(success: data[DataStart] == 0, rawData: data, data: nil)
    }
}
