//
//  DanaHistoryCarbohydrates.swift
//  DanaKit
//
//  Created by Bastiaan Verhaar on 13/12/2023.
//  Copyright © 2023 Randall Knutson. All rights reserved.
//

let CommandHistoryCarbohydrates = (DanaPacketType.TYPE_RESPONSE & 0xff << 8) + (DanaPacketType.OPCODE_REVIEW__CARBOHYDRATE & 0xff)

func generatePacketHistoryCarbohydrates(options: PacketHistoryBase) -> DanaGeneratePacket {
    return DanaGeneratePacket(
        opCode: DanaPacketType.OPCODE_REVIEW__CARBOHYDRATE,
        data: generatePacketHistoryData(options: options)
    )
}
