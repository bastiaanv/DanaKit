//
//  DanaPacketBasalCancelTemporary.swift
//  DanaKit
//
//  Created by Bastiaan Verhaar on 10/12/2023.
//  Copyright © 2023 Randall Knutson. All rights reserved.
//

func generatePacketBasalCancelTemporary() -> DanaGeneratePacket {
    return DanaGeneratePacket(opCode: DanaPacketType.OPCODE_BASAL__CANCEL_TEMPORARY_BASAL, data: nil)
}

func parsePacketBasalCancelTemporary(data: Data) -> DanaParsePacket<Any?> {
    let success = data[DataStart] == 0
    return DanaParsePacket(success: success, data: nil)
}
