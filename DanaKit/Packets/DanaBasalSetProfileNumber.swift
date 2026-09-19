struct PacketBasalSetProfileNumber {
    let profileNumber: UInt8
}

class DanaBasalSetProfileNumber : DanaKitBasePacket {
    let name = "Basal_SetProfileNumber"
    let opCode = DanaPacketType.OPCODE_BASAL__SET_PROFILE_NUMBER
    
    private let options: PacketBasalSetProfileNumber
    init(options: PacketBasalSetProfileNumber) {
        self.options = options
    }
    
    func generate() -> Data {
        Data([options.profileNumber & 0xFF])
    }
    
    func parse(data: Data, usingUtc _: Bool?) -> any DanaParsePacketProtocol {
        DanaParsePacket<String>(success: data[DataStart] == 0, rawData: data, data: nil)
    }
}
