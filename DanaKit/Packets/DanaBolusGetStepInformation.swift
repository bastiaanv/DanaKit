struct PacketBolusGetStepInformation: Codable {
    var bolusType: UInt8
    var initialBolusAmount: Double
    var lastBolusTime: Date
    var lastBolusAmount: Double
    var maxBolus: Double
    var bolusStep: UInt8
}

class DanaBolusGetStepInformation: DanaKitBasePacket {
    let name = "Bolus_GetStepInformation"
    let opCode = DanaPacketType.OPCODE_BOLUS__GET_STEP_BOLUS_INFORMATION

    func generate() -> Data {
        Data()
    }

    func parse(data: Data, usingUtc _: Bool?) -> any DanaParsePacketProtocol {
        let lastBolusTime = Calendar.current.date(
            bySettingHour: Int(data[DataStart + 4]),
            minute: Int(data[DataStart + 5]),
            second: 0,
            of: Date()
        ) ?? Date()

        return DanaParsePacket(success: data[DataStart] == 0, rawData: data, data: PacketBolusGetStepInformation(
            bolusType: data[DataStart + 1],
            initialBolusAmount: Double(data.uint16(at: DataStart + 2)) / 100,
            lastBolusTime: lastBolusTime,
            lastBolusAmount: Double(data.uint16(at: DataStart + 6)) / 100,
            maxBolus: Double(data.uint16(at: DataStart + 8)) / 100,
            bolusStep: data[DataStart + 10]
        ))
    }
}
