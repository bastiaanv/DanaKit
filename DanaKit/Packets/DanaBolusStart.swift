//
//  DanaBolusStart.swift
//  DanaKit
//
//  Created by Bastiaan Verhaar on 10/12/2023.
//  Copyright © 2023 Randall Knutson. All rights reserved.
//

public enum BolusSpeed: UInt8 {
    case speed12 = 0
    case speed30 = 1
    case speed60 = 2
}

struct PacketBolusStart {
    var amount: Double
    var speed: BolusSpeed
}

let CommandBolusStart: UInt16 = (UInt16(DanaPacketType.TYPE_RESPONSE & 0xff) << 8) + UInt16(DanaPacketType.OPCODE_BOLUS__SET_STEP_BOLUS_START & 0xff)

func generatePacketBolusStart(options: PacketBolusStart) -> DanaGeneratePacket {
    let bolusRate = UInt16(options.amount * 100)
    var data = Data(count: 3)
    data[0] = UInt8(bolusRate & 0xff)
    data[1] = UInt8((bolusRate >> 8) & 0xff)
    data[2] = options.speed.rawValue

    return DanaGeneratePacket(opCode: DanaPacketType.OPCODE_BOLUS__SET_STEP_BOLUS_START, data: data)
}

/**
 * Error codes:
 * 0x04 => Bolus timeout active
 * 0x10 => Max bolus violation
 * 0x20 => Command error
 * 0x40 => Speed error
 * 0x80 => Insulin limit violation
 */
func parsePacketBolusStart(data: Data) -> DanaParsePacket<Any> {
    return DanaParsePacket(success: data[DataStart] == 0, data: nil)
}
