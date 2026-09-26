struct PacketGeneralSetPumpTimeUtcWithTimezone {
    let time: Date
    let zoneOffset: UInt8
}

class DanaGeneralSetPumpTimeUtcWithTimezone: DanaKitBasePacket {
    let name = "General_SetPumpTimeUtcWithTimezone"
    let opCode = DanaPacketType.OPCODE_OPTION__SET_PUMP_UTC_AND_TIME_ZONE

    private let options: PacketGeneralSetPumpTimeUtcWithTimezone
    init(options: PacketGeneralSetPumpTimeUtcWithTimezone) {
        self.options = options
    }

    func generate() throws -> Data {
        var data = Data(count: 7)
        data.addDate(at: 0, date: options.time)
        data[6] = options.zoneOffset

        return data
    }

    func parse(data: Data, usingUtc _: Bool?) -> any DanaParsePacketProtocol {
        DanaParsePacket<String>(success: data[DataStart] == 0, rawData: data, data: nil)
    }
}
