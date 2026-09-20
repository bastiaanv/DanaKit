struct PacketBasalSetTemporary {
    /// Ratio is in percentage
    let temporaryBasalRatio: UInt8

    /// Only whole hours are accepted
    let temporaryBasalDuration: UInt8
}

class DanaBasalSetTemporary : DanaKitBasePacket {
    let name = "Basal_SetTemporary"
    let opCode = DanaPacketType.OPCODE_BASAL__SET_TEMPORARY_BASAL
    
    private let options: PacketBasalSetTemporary
    init(options: PacketBasalSetTemporary) {
        self.options = options
    }
    
    func generate() -> Data {
        Data([options.temporaryBasalRatio, options.temporaryBasalDuration])
    }
    
    func parse(data: Data, usingUtc _: Bool?) -> any DanaParsePacketProtocol {
        DanaParsePacket<String>(success: data[DataStart] == 0, rawData: data, data: nil)
    }
}
