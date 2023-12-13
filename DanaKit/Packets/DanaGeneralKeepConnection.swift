//
//  DanaGeneralKeepConnection.swift
//  DanaKit
//
//  Created by Bastiaan Verhaar on 13/12/2023.
//  Copyright © 2023 Randall Knutson. All rights reserved.
//

let CommandGeneralKeepConnection = (DanaPacketType.TYPE_RESPONSE & 0xff << 8) + (DanaPacketType.OPCODE_ETC__KEEP_CONNECTION & 0xff)

func generatePacketGeneralKeepConnection() -> DanaGeneratePacket {
    return DanaGeneratePacket(
        opCode: DanaPacketType.OPCODE_ETC__KEEP_CONNECTION,
        data: nil
    )
}

func parsePacketGeneralKeepConnection(data: Data) -> DanaParsePacket<Any?> {
    return DanaParsePacket(
        success: data[DataStart] == 0,
        data: nil
    )
}
