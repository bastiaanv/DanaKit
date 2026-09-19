class DanaBasalSetSuspendOn : DanaKitBasePacket {
    let name = "Basal_SetSuspendOn"
    let opCode = DanaPacketType.OPCODE_BASAL__SET_SUSPEND_ON
    
    func generate() -> Data {
        Data()
    }
    
    func parse(data: Data, usingUtc _: Bool?) -> any DanaParsePacketProtocol {
        DanaParsePacket<String>(success: data[DataStart] == 0, rawData: data, data: nil)
    }
}
