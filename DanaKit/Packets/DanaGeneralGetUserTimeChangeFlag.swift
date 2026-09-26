struct PacketGeneralGetUserTimeChangeFlag: Codable {
    var userTimeChangeFlag: UInt8
}

class DanaGeneralGetUserTimeChangeFlag: DanaKitBasePacket {
    let name = "General_GetUserTimeChangeFlag"
    let opCode = DanaPacketType.OPCODE_REVIEW__GET_USER_TIME_CHANGE_FLAG

    func generate() throws -> Data {
        Data()
    }

    func parse(data: Data, usingUtc _: Bool?) -> any DanaParsePacketProtocol {
        guard data.count >= 3 else {
            return DanaParsePacket(
                success: false,
                rawData: data,
                data: PacketGeneralGetUserTimeChangeFlag(userTimeChangeFlag: 0)
            )
        }

        return DanaParsePacket(
            success: true,
            rawData: data,
            data: PacketGeneralGetUserTimeChangeFlag(userTimeChangeFlag: data[DataStart])
        )
    }
}
