struct PacketNotifyDeliveryRateDisplay: Codable {
    var deliveredInsulin: Double
}

class DanaNotifyDeliveryRateDisplay : DanaKitBasePacket {
    let name = "Notify_DeliveryRateDisplay"
    let opCode = DanaPacketType.OPCODE_NOTIFY__DELIVERY_RATE_DISPLAY

    func generate() throws -> Data {
        Data()
    }
    
    func parse(data: Data, usingUtc _: Bool?) -> any DanaParsePacketProtocol {
        DanaParsePacket(
            success: true,
            notifyType: (UInt16(DanaPacketType.TYPE_NOTIFY & 0xFF) << 8) + UInt16(opCode),
            rawData: data,
            data: PacketNotifyDeliveryRateDisplay(
                deliveredInsulin: Double(data.uint16(at: DataStart)) / 100
            )
        )
    }
}
