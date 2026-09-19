struct PacketBolusSet24CIRCFArray {
    /** 0 => mg/dl, 1 => mmol/L */
    var unit: UInt8
    var ic: [Double]
    var isf: [UInt16]
}

class DanaBolusSet24CIRCFArray : DanaKitBasePacket {
    let name = "Bolus_Set24CIRCFArray"
    let opCode = DanaPacketType.OPCODE_BOLUS__SET_24_CIR_CF_ARRAY
    
    private let options: PacketBolusSet24CIRCFArray
    init(options: PacketBolusSet24CIRCFArray) {
        self.options = options
    }

    func generate() throws -> Data {
        guard options.isf.count == 24, options.ic.count == 24 else {
            throw NSError(domain: "INVALID_LENGTH", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid length isf or ic"])
        }

        var adjustedISF = options.isf
        if options.unit == 1 {
            adjustedISF = options.isf.map { $0 * 100 }
        }

        var data = Data(count: 96)
        for i in 0 ..< 24 {
            let roundedIC = UInt16(Double(options.ic[i]).rounded())
            let roundedISF = UInt16(Double(adjustedISF[i]).rounded())

            data[i * 2] = UInt8(roundedIC & 0xFF)
            data[i * 2 + 1] = UInt8((roundedIC >> 8) & 0xFF)

            data[i * 2 + 48] = UInt8(roundedISF & 0xFF)
            data[i * 2 + 49] = UInt8((roundedISF >> 8) & 0xFF)
        }
        
        return data
    }
    
    func parse(data: Data, usingUtc _: Bool?) -> any DanaParsePacketProtocol {
        DanaParsePacket<String>(success: data[DataStart] == 0, rawData: data, data: nil)
    }
}
