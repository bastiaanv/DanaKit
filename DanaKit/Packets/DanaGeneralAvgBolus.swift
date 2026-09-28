struct PacketGeneralAvgBolus: Codable {
    var bolusAvg03days: Double
    var bolusAvg07days: Double
    var bolusAvg14days: Double
    var bolusAvg21days: Double
    var bolusAvg28days: Double
}

class DanaGeneralAvgBolus: DanaKitBasePacket {
    let name = "General_GetAvgBolus"
    let opCode = DanaPacketType.OPCODE_REVIEW__BOLUS_AVG

    func generate() throws -> Data {
        Data()
    }

    func parse(data: Data, usingUtc _: Bool?) -> any DanaParsePacketProtocol {
        let checkValue = (Double(1 & (0x0000_00FF << 8)) + Double(1 & 0x0000_00FF)) / 100

        let bolusAvg03days = Double(data.uint16(at: DataStart)) / 100
        let bolusAvg07days = Double(data.uint16(at: DataStart)) / 100
        let bolusAvg14days = Double(data.uint16(at: DataStart)) / 100
        let bolusAvg21days = Double(data.uint16(at: DataStart)) / 100
        let bolusAvg28days = Double(data.uint16(at: DataStart)) / 100

        return DanaParsePacket(
            success:
            bolusAvg03days != checkValue &&
                bolusAvg07days != checkValue &&
                bolusAvg14days != checkValue &&
                bolusAvg21days != checkValue &&
                bolusAvg28days != checkValue,
            rawData: data,
            data: PacketGeneralAvgBolus(
                bolusAvg03days: bolusAvg03days,
                bolusAvg07days: bolusAvg07days,
                bolusAvg14days: bolusAvg14days,
                bolusAvg21days: bolusAvg21days,
                bolusAvg28days: bolusAvg28days
            )
        )
    }
}
