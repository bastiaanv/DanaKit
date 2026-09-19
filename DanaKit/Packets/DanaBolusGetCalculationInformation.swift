struct PacketBolusGetCalculationInformation: Codable {
    var currentBg: UInt16
    var carbohydrate: UInt16
    var currentTarget: UInt16
    var currentCIR: UInt16
    var currentCF: UInt16

    /** 0 = mg/dl, 1 = mmol/L */
    var units: UInt8
}

class DanaBolusGetCalculationInformation : DanaKitBasePacket {
    let name = "Bolus_GetCalculationInformation"
    let opCode = DanaPacketType.OPCODE_BOLUS__GET_CALCULATION_INFORMATION

    func generate() -> Data {
        Data()
    }
    
    func parse(data: Data, usingUtc _: Bool?) -> any DanaParsePacketProtocol {
        let currentBg = data.uint16(at: DataStart + 1)
        let carbohydrate = data.uint16(at: DataStart + 3)
        let currentTarget = data.uint16(at: DataStart + 5)
        let currentCIR = data.uint16(at: DataStart + 7)
        let currentCF = data.uint16(at: DataStart + 9)
        let units = data[DataStart + 11]

        return DanaParsePacket(success: data[DataStart] == 0, rawData: data, data: PacketBolusGetCalculationInformation(
            currentBg: units == 1 ? currentBg / 100 : currentBg,
            carbohydrate: carbohydrate,
            currentTarget: units == 1 ? currentTarget / 100 : currentTarget,
            currentCIR: currentCIR,
            currentCF: units == 1 ? currentCF / 100 : currentCF,
            units: units
        ))
    }
}
