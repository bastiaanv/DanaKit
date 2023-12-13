//
//  DanaBolusSet24CIRCFArray.swift
//  DanaKit
//
//  Created by Bastiaan Verhaar on 10/12/2023.
//  Copyright © 2023 Randall Knutson. All rights reserved.
//

struct PacketBolusSet24CIRCFArray {
    /** 0 => mg/dl, 1 => mmol/L */
    var unit: UInt8
    var ic: [Double]
    var isf: [UInt16]
}

let CommandBolusSet24CIRCFArray: UInt16 = (UInt16(DanaPacketType.TYPE_RESPONSE & 0xff) << 8) + UInt16(DanaPacketType.OPCODE_BOLUS__SET_24_CIR_CF_ARRAY & 0xff)

func generatePacketBolusSet24CIRCFArray(options: PacketBolusSet24CIRCFArray) throws -> DanaGeneratePacket {
    guard options.isf.count == 24 && options.ic.count == 24 else {
        throw NSError(domain: "INVALID_LENGTH", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid length isf or ic"])
    }

    var adjustedISF = options.isf
    if options.unit == 1 {
        adjustedISF = options.isf.map { $0 * 100 }
    }

    var data = Data(count: 96)
    for i in 0..<24 {
        let roundedIC = UInt16(Double(options.ic[i]).rounded())
        let roundedISF = UInt16(Double(adjustedISF[i]).rounded())

        data.replaceSubrange(i * 2..<i * 2 + 2, with: withUnsafeBytes(of: roundedIC) { Data($0) })
        data.replaceSubrange(i * 2 + 48..<i * 2 + 50, with: withUnsafeBytes(of: roundedISF) { Data($0) })
    }

    return DanaGeneratePacket(opCode: DanaPacketType.OPCODE_BOLUS__SET_24_CIR_CF_ARRAY, data: data)
}

func parsePacketBolusSet24CIRCFArray(data: Data) -> DanaParsePacket<Any?> {
    return DanaParsePacket(success: data[DataStart] == 0, data: nil)
}
