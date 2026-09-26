struct PacketNotifyMissedBolus: Codable {
    var startTime: Date
    var endTime: Date
}

class DanaNotifyMissedBolus: DanaKitBasePacket {
    let name = "Notify_BolusMissed"
    let opCode = DanaPacketType.OPCODE_NOTIFY__MISSED_BOLUS_ALARM

    func generate() throws -> Data {
        Data()
    }

    func parse(data: Data, usingUtc _: Bool?) -> any DanaParsePacketProtocol {
        let startTime = Date(
            timeIntervalSinceReferenceDate: TimeInterval(
                (UInt16(data[DataStart]) * 3600 + UInt16(data[DataStart + 1]) * 60) * 60
            )
        )

        let endTime = Date(
            timeIntervalSinceReferenceDate: TimeInterval(
                (UInt16(data[DataStart + 2]) * 3600 + UInt16(data[DataStart + 3]) * 60) * 60
            )
        )

        return DanaParsePacket(
            success: data[DataStart] != 0x01 && data[DataStart + 1] != 0x01 && data[DataStart + 2] != 0x01 &&
                data[DataStart + 3] !=
                0x01,
            notifyType: (UInt16(DanaPacketType.TYPE_NOTIFY & 0xFF) << 8) + UInt16(opCode),
            rawData: data,
            data: PacketNotifyMissedBolus(
                startTime: startTime,
                endTime: endTime
            )
        )
    }
}
