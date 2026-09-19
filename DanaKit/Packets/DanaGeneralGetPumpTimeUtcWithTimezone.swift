struct PacketGeneralGetPumpTimeUtcWithTimezone: Codable {
    var time: Date
    var timezoneOffset: Int
}

class DanaGeneralGetPumpTimeUtcWithTimezone : DanaKitBasePacket {
    let name = "General_GetPumpTimeUtcWithTimezone"
    let opCode = DanaPacketType.OPCODE_OPTION__GET_PUMP_UTC_AND_TIME_ZONE

    func generate() throws -> Data {
        Data()
    }
    
    func parse(data: Data, usingUtc _: Bool?) -> any DanaParsePacketProtocol {
        let timezoneOffsetInHours = Int(Int8(bitPattern: data[DataStart + 6]))

        let time = DateComponents(
            year: 2000 + Int(data[DataStart]),
            month: Int(data[DataStart + 1]),
            day: Int(data[DataStart + 2]),
            hour: Int(data[DataStart + 3]) + timezoneOffsetInHours,
            minute: Int(data[DataStart + 4]),
            second: Int(data[DataStart + 5])
        )

        guard let parsedTime = Calendar.current.date(from: time) else {
            // Handle error, if needed
            return DanaParsePacket<String>(success: false, rawData: data, data: nil)
        }

        return DanaParsePacket(
            success: true,
            rawData: data,
            data: PacketGeneralGetPumpTimeUtcWithTimezone(time: parsedTime, timezoneOffset: timezoneOffsetInHours)
        )
    }
}
