struct PacketNotifyAlarm: Codable {
    var code: UInt8
    var alert: PumpManagerAlert
}

class DanaNotifyAlarm: DanaKitBasePacket {
    let name = "Notify_Alarm"
    let opCode = DanaPacketType.OPCODE_NOTIFY__ALARM

    func generate() throws -> Data {
        Data()
    }

    func parse(data: Data, usingUtc _: Bool?) -> any DanaParsePacketProtocol {
        let DANA_NOTIFY_ALARM: [Int: PumpManagerAlert] = [
            0x01: PumpManagerAlert.batteryZeroPercent(data),
            0x02: PumpManagerAlert.pumpError(data),
            0x03: PumpManagerAlert.occlusion(data),
            0x04: PumpManagerAlert.lowBattery(data),
            0x05: PumpManagerAlert.shutdown(data),
            0x06: PumpManagerAlert.basalCompare(data),
            0x07: PumpManagerAlert.bloodSugarMeasure(data),
            0xFF: PumpManagerAlert.bloodSugarMeasure(data),
            0x08: PumpManagerAlert.remainingInsulinLevel(data),
            0xFE: PumpManagerAlert.remainingInsulinLevel(data),
            0x09: PumpManagerAlert.emptyReservoir(data),
            0x0A: PumpManagerAlert.checkShaft(data),
            0x0B: PumpManagerAlert.basalMax(data),
            0x0C: PumpManagerAlert.dailyMax(data),
            0xFD: PumpManagerAlert.bloodSugarCheckMiss(data)
        ]

        let code = data[DataStart]
        let alert = DANA_NOTIFY_ALARM[Int(code)] ?? PumpManagerAlert.unknown(nil)

        return DanaParsePacket(
            success: true,
            notifyType: (UInt16(DanaPacketType.TYPE_NOTIFY & 0xFF) << 8) + UInt16(opCode),
            rawData: data,
            data: PacketNotifyAlarm(
                code: code,
                alert: alert
            )
        )
    }
}
