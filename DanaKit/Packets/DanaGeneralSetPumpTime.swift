struct PacketGeneralSetPumpTime {
    let time: Date
}

class DanaGeneralSetPumpTime: DanaKitBasePacket {
    let name = "General_SetPumpTime"
    let opCode = DanaPacketType.OPCODE_OPTION__SET_PUMP_TIME

    private let options: PacketGeneralSetPumpTime
    init(options: PacketGeneralSetPumpTime) {
        self.options = options
    }

    func generate() throws -> Data {
        var data = Data(count: 6)
        data.addDate(at: 0, date: options.time, utc: false)

        return data
    }

    func parse(data: Data, usingUtc _: Bool?) -> any DanaParsePacketProtocol {
        DanaParsePacket<String>(success: data[DataStart] == 0, rawData: data, data: nil)
    }
}
