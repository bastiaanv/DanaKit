struct PacketBolusSetOption {
    var extendedBolusOptionOnOff: UInt8
    var bolusCalculationOption: UInt8
    var missedBolusConfig: UInt8
    var missedBolus01StartHour: UInt8
    var missedBolus01StartMin: UInt8
    var missedBolus01EndHour: UInt8
    var missedBolus01EndMin: UInt8
    var missedBolus02StartHour: UInt8
    var missedBolus02StartMin: UInt8
    var missedBolus02EndHour: UInt8
    var missedBolus02EndMin: UInt8
    var missedBolus03StartHour: UInt8
    var missedBolus03StartMin: UInt8
    var missedBolus03EndHour: UInt8
    var missedBolus03EndMin: UInt8
    var missedBolus04StartHour: UInt8
    var missedBolus04StartMin: UInt8
    var missedBolus04EndHour: UInt8
    var missedBolus04EndMin: UInt8
}

class DanaBolusSetOption : DanaKitBasePacket {
    let name = "Bolus_SetOption"
    let opCode = DanaPacketType.OPCODE_BOLUS__SET_BOLUS_OPTION
    
    private let options: PacketBolusSetOption
    init(options: PacketBolusSetOption) {
        self.options = options
    }

    func generate() throws -> Data {
        Data([
            options.extendedBolusOptionOnOff,
            options.bolusCalculationOption,
            options.missedBolusConfig,
            options.missedBolus01StartHour,
            options.missedBolus01StartMin,
            options.missedBolus01EndHour,
            options.missedBolus01EndMin,
            options.missedBolus02StartHour,
            options.missedBolus02StartMin,
            options.missedBolus02EndHour,
            options.missedBolus02EndMin,
            options.missedBolus03StartHour,
            options.missedBolus03StartMin,
            options.missedBolus03EndHour,
            options.missedBolus03EndMin,
            options.missedBolus04StartHour,
            options.missedBolus04StartMin,
            options.missedBolus04EndHour,
            options.missedBolus04EndMin
        ])
    }
    
    func parse(data: Data, usingUtc _: Bool?) -> any DanaParsePacketProtocol {
        DanaParsePacket<String>(success: data[DataStart] == 0, rawData: data, data: nil)
    }
}
