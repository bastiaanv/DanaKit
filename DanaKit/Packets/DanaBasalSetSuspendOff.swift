class DanaBasalSetSuspendOff: DanaKitBasePacket {
    let name = "Basal_SetSuspendOff"
    let opCode = DanaPacketType.OPCODE_BASAL__SET_SUSPEND_OFF

    func generate() -> Data {
        Data()
    }

    func parse(data: Data, usingUtc _: Bool?) -> any DanaParsePacketProtocol {
        DanaParsePacket<String>(success: data[DataStart] == 0, rawData: data, data: nil)
    }
}
