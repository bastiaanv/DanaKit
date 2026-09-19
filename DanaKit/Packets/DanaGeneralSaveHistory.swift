struct PacketGeneralSaveHistory {
    var historyType: UInt8
    var historyDate: Date
    var historyCode: UInt8
    var historyValue: UInt16
}

class DanaGeneralSaveHistory : DanaKitBasePacket {
    let name = "General_SetHistory"
    let opCode = DanaPacketType.OPCODE_ETC__SET_HISTORY_SAVE
    
    private let options: PacketGeneralSaveHistory
    init(options: PacketGeneralSaveHistory) {
        self.options = options
    }

    func generate() throws -> Data {
        var data = Data(count: 10)
        data[0] = options.historyType
        data.addDate(at: 1, date: options.historyDate)

        data[7] = options.historyCode
        data[8] = UInt8(options.historyValue & 0xFF)
        data[9] = UInt8((options.historyValue >> 8) & 0xFF)
        
        return data
    }
    
    func parse(data: Data, usingUtc _: Bool?) -> any DanaParsePacketProtocol {
        DanaParsePacket<String>(success: data[DataStart] == 0, rawData: data, data: nil)
    }
}
