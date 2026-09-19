struct PacketBasalGetProfileNumber: Codable {
    let activeProfile: UInt8
}

class DanaBasalGetProfileNumber : DanaKitBasePacket {
    let name = "Basal_GetProfileNumber"
    let opCode = DanaPacketType.OPCODE_BASAL__GET_PROFILE_BASAL_RATE
    
    func generate() -> Data {
        Data()
    }
    
    func parse(data: Data, usingUtc _: Bool?) -> any DanaParsePacketProtocol {
        DanaParsePacket<PacketBasalGetProfileNumber>(success: true, rawData: data, data: PacketBasalGetProfileNumber(activeProfile: data[DataStart]))
    }
}
