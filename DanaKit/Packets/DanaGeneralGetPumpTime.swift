struct PacketGeneralGetPumpTime: Codable {
    var time: Date
}

class DanaGeneralGetPumpTime : DanaKitBasePacket {
    let name = "General_GetPumpTime"
    let opCode = DanaPacketType.OPCODE_OPTION__GET_PUMP_TIME

    func generate() throws -> Data {
        Data()
    }
    
    func parse(data: Data, usingUtc _: Bool?) -> any DanaParsePacketProtocol {
        let time = DateComponents(
            year: 2000 + Int(data[DataStart]),
            month: Int(data[DataStart + 1]),
            day: Int(data[DataStart + 2]),
            hour: Int(data[DataStart + 3]),
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
            data: PacketGeneralGetPumpTime(time: parsedTime)
        )
    }
}
