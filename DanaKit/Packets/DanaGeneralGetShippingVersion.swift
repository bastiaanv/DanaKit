struct PacketGeneralGetShippingVersion: Codable {
    var bleModel: String
}

class DanaGeneralGetShippingVersion: DanaKitBasePacket {
    let name = "General_GetShippingVersion"
    let opCode = DanaPacketType.OPCODE_GENERAL__GET_SHIPPING_VERSION

    func generate() throws -> Data {
        Data()
    }

    func parse(data: Data, usingUtc _: Bool?) -> any DanaParsePacketProtocol {
        DanaParsePacket(
            success: true,
            rawData: data,
            data: PacketGeneralGetShippingVersion(
                bleModel: String(data: data.subdata(in: DataStart ..< data.count), encoding: .utf8) ?? ""
            )
        )
    }
}
