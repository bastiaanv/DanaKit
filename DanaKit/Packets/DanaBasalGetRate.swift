struct PacketBasalGetRate: Codable {
    let maxBasal: Double
    let basalStep: Double
    let basalProfile: [Double]
}

class DanaBasalGetRate : DanaKitBasePacket {
    let name = "Basal_GetRate"
    let opCode = DanaPacketType.OPCODE_BASAL__GET_BASAL_RATE
    
    func generate() -> Data {
        Data()
    }
    
    func parse(data: Data, usingUtc _: Bool?) -> any DanaParsePacketProtocol {
        let maxBasal = Double(data.uint16(at: DataStart)) / 100.0
        let basalStep = Double(data[DataStart + 2]) / 100.0

        var basalProfile: [Double] = []
        for i in 0 ..< 24 {
            let index = DataStart + 3 + i * 2
            let basalValue = Double(data.uint16(at: index)) / 100.0
            basalProfile.append(basalValue)
        }

        return DanaParsePacket<PacketBasalGetRate>(
            success: basalStep < 1,
            rawData: data,
            data: PacketBasalGetRate(maxBasal: maxBasal, basalStep: basalStep, basalProfile: basalProfile)
        )
    }
}
