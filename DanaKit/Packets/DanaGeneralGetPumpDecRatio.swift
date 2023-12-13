//
//  DanaGeneralGetPumpDecRatio.swift
//  DanaKit
//
//  Created by Bastiaan Verhaar on 13/12/2023.
//  Copyright © 2023 Randall Knutson. All rights reserved.
//

struct PacketGeneralGetPumpDecRatio {
    var decRatio: UInt8
}

let CommandGeneralGetPumpDecRatio = (DanaPacketType.TYPE_RESPONSE & 0xff << 8) + (DanaPacketType.OPCODE_REVIEW__GET_PUMP_DEC_RATIO & 0xff)

func generatePacketGeneralGetPumpDecRatio() -> DanaGeneratePacket {
    return DanaGeneratePacket(
        opCode: DanaPacketType.OPCODE_REVIEW__GET_PUMP_DEC_RATIO,
        data: nil
    )
}

func parsePacketGeneralGetPumpDecRatio(data: Data) -> DanaParsePacket<PacketGeneralGetPumpDecRatio> {
    return DanaParsePacket(
        success: true,
        data: PacketGeneralGetPumpDecRatio(
            decRatio: data[DataStart] * 5
        )
    )
}
