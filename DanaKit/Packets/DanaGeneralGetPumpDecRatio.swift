struct PacketGeneralGetPumpDecRatio: Codable {
    var decRatio: UInt8
}

class DanaGeneralGetPumpDecRatio : DanaKitBasePacket {
    let name = "General_GetPumpDecRatio"
    let opCode = DanaPacketType.OPCODE_REVIEW__GET_PUMP_DEC_RATIO

    func generate() throws -> Data {
        Data()
    }
    
    func parse(data: Data, usingUtc _: Bool?) -> any DanaParsePacketProtocol {
        DanaParsePacket(
            success: true,
            rawData: data,
            data: PacketGeneralGetPumpDecRatio(
                decRatio: data[DataStart] * 5
            )
        )
    }
}
