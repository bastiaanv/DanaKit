struct PacketBasalSetProfileRate {
    var profileNumber: UInt8
    var profileBasalRate: [Double]
}

class DanaBasalSetProfileRate: DanaKitBasePacket {
    let name = "Basal_SetRate"
    let opCode = DanaPacketType.OPCODE_BASAL__SET_PROFILE_BASAL_RATE

    private let options: PacketBasalSetProfileRate
    init(options: PacketBasalSetProfileRate) {
        self.options = options
    }

    func generate() throws -> Data {
        guard options.profileBasalRate.count == 24 else {
            throw NSError(
                domain: "INVALID_LENGTH",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Invalid basal rate. Expected length = 24"]
            )
        }

        var dataArray = [UInt8](repeating: 0, count: 49)
        dataArray[0] = options.profileNumber

        for i in 0 ..< 24 {
            let rate = UInt16(options.profileBasalRate[i] * 100)
            dataArray[1 + i * 2] = UInt8(rate & 0xFF)
            dataArray[2 + i * 2] = UInt8((rate >> 8) & 0xFF)
        }

        return Data(dataArray)
    }

    func parse(data: Data, usingUtc _: Bool?) -> any DanaParsePacketProtocol {
        DanaParsePacket<String>(success: data[DataStart] == 0, rawData: data, data: nil)
    }
}
