//
//  DanaGeneralGetUserTimeChangeFlag.swift
//  DanaKit
//
//  Created by Bastiaan Verhaar on 13/12/2023.
//  Copyright © 2023 Randall Knutson. All rights reserved.
//

struct PacketGeneralGetUserTimeChangeFlag {
    var userTimeChangeFlag: UInt8
}

let CommandGeneralGetUserTimeChangeFlag = (DanaPacketType.TYPE_RESPONSE & 0xff << 8) + (DanaPacketType.OPCODE_REVIEW__GET_USER_TIME_CHANGE_FLAG & 0xff)

func generatePacketGeneralGetUserTimeChangeFlag() -> DanaGeneratePacket {
    return DanaGeneratePacket(
        opCode: DanaPacketType.OPCODE_REVIEW__GET_USER_TIME_CHANGE_FLAG,
        data: nil
    )
}

func parsePacketGeneralGetUserTimeChangeFlag(data: Data) -> DanaParsePacket<PacketGeneralGetUserTimeChangeFlag> {
    guard data.count >= 3 else {
        return DanaParsePacket(
            success: false,
            data: PacketGeneralGetUserTimeChangeFlag(userTimeChangeFlag: 0)
        )
    }

    return DanaParsePacket(
        success: true,
        data: PacketGeneralGetUserTimeChangeFlag(userTimeChangeFlag: data[DataStart])
    )
}
