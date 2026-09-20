struct PacketGeneralGetPumpCheck: Codable {
    let hwModel: UInt8
    let protocolCode: UInt8
    let productCode: UInt8
}

class DanaGeneralGetPumpCheck: DanaKitBasePacket {
    let name = "General_GetPumpCheck"
    let opCode = DanaPacketType.OPCODE_REVIEW__GET_PUMP_CHECK

    func generate() throws -> Data {
        Data()
    }

    func parse(data: Data, usingUtc _: Bool?) -> any DanaParsePacketProtocol {
        DanaParsePacket(
            success: data[4] < 4, // Unsupported hardware...
            rawData: data,
            data: PacketGeneralGetPumpCheck(
                hwModel: data[DataStart],
                protocolCode: data[DataStart + 1],
                productCode: data[DataStart + 2]
            )
        )
    }
}
