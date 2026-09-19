struct PacketGeneralSetHistoryUploadMode {
    /**
     * 1 -> Turn on history upload mode, 0 -> turn off history upload mode.
     *
     * Need to do this before and after fetching the history from pump
     */
    let mode: UInt8
}

class DanaGeneralSetHistoryUploadMode : DanaKitBasePacket {
    let name = "General_SetHistoryUploadMode"
    let opCode = DanaPacketType.OPCODE_REVIEW__SET_HISTORY_UPLOAD_MODE
    
    private let options: PacketGeneralSetHistoryUploadMode
    init(options: PacketGeneralSetHistoryUploadMode) {
        self.options = options
    }

    func generate() throws -> Data {
        Data([options.mode])
    }
    
    func parse(data: Data, usingUtc _: Bool?) -> any DanaParsePacketProtocol {
        DanaParsePacket<String>(success: data[DataStart] == 0, rawData: data, data: nil)
    }
}
