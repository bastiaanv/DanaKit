struct PacketBolusSetExtended {
    var extendedAmount: UInt16
    var extendedDurationInHalfHours: UInt8
}

class DanaBolusSetExtended : DanaKitBasePacket {
    let name = "Bolus_SetExtended"
    let opCode = DanaPacketType.OPCODE_BOLUS__SET_EXTENDED_BOLUS
    
    private let options: PacketBolusSetExtended
    init(options: PacketBolusSetExtended) {
        self.options = options
    }

    func generate() throws -> Data {
        Data([
            UInt8(options.extendedAmount & 0xFF),
            UInt8((options.extendedAmount >> 8) & 0xFF),
            options.extendedDurationInHalfHours
        ])
    }
    
    func parse(data: Data, usingUtc _: Bool?) -> any DanaParsePacketProtocol {
        DanaParsePacket<String>(success: data[DataStart] == 0, rawData: data, data: nil)
    }
}
