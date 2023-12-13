//
//  DanaHistorySuspend.swift
//  DanaKit
//
//  Created by Bastiaan Verhaar on 13/12/2023.
//  Copyright © 2023 Randall Knutson. All rights reserved.
//

let CommandHistorySuspend = (DanaPacketType.TYPE_RESPONSE & 0xff << 8) + (DanaPacketType.OPCODE_REVIEW__SUSPEND & 0xff)

func generatePacketHistorySuspend(options: PacketHistoryBase) -> DanaGeneratePacket {
    return DanaGeneratePacket(
        opCode: DanaPacketType.OPCODE_REVIEW__SUSPEND,
        data: generatePacketHistoryData(options: options)
    )
}
