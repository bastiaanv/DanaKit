struct PacketBolusGet24CIRCFArray: Codable {
    var unit: UInt8

    /** Length: 24, value per hour. insulin to carbohydrate ratio */
    var ic: [UInt16]

    /** Length: 24, value per hour. insulin sensitivity factor */
    var isf: [UInt16]
}

class DanaBolusGet24CIRCFArray: DanaKitBasePacket {
    let name = "Bolus_Get24CIRCFArray"
    let opCode = DanaPacketType.OPCODE_BOLUS__GET_24_CIR_CF_ARRAY

    func generate() -> Data {
        Data()
    }

    func parse(data: Data, usingUtc _: Bool?) -> any DanaParsePacketProtocol {
        var isf: [UInt16] = []
        var ic: [UInt16] = []
        let unit = data[DataStart]

        for i in 0 ..< 24 {
            ic.append(data.uint16(at: DataStart + 1 + 2 * i))
            isf.append(data.uint16(at: DataStart + 49 + 2 * i) / (unit == 0 ? 1 : 100))
        }

        return DanaParsePacket(
            success: unit == 0 || unit == 1,
            rawData: data,
            data: PacketBolusGet24CIRCFArray(unit: unit, ic: ic, isf: isf)
        )
    }
}
