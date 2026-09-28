struct PacketBolusStart {
    var amount: Double
    var speed: BolusSpeed
}

class DanaBolusStart: DanaKitBasePacket {
    let name = "Bolus_Start"
    let opCode = DanaPacketType.OPCODE_BOLUS__SET_STEP_BOLUS_START

    private let options: PacketBolusStart
    init(options: PacketBolusStart) {
        self.options = options
    }

    func generate() throws -> Data {
        let bolusRate = UInt16(options.amount * 100)

        return Data([
            UInt8(bolusRate & 0xFF),
            UInt8((bolusRate >> 8) & 0xFF),
            options.speed.rawValue
        ])
    }

    func parse(data: Data, usingUtc _: Bool?) -> any DanaParsePacketProtocol {
        DanaParsePacket<String>(success: data[DataStart] == 0, rawData: data, data: nil)
    }

    /**
     * Error codes:
     * 0x01 => Pump suspended
     * 0x04 => Bolus timeout active
     * 0x10 => Max bolus violation
     * 0x20 => Command error (Unknown what this error means)
     * 0x40 => Speed error (Can only happen during development)
     * 0x80 => Insulin limit violation
     */
    func transformBolusError(code: UInt8) -> DanaKitPumpManagerError {
        switch code {
        case 0x01:
            return DanaKitPumpManagerError.pumpSuspended
        case 0x04:
            return DanaKitPumpManagerError.bolusTimeoutActive
        case 0x10:
            return DanaKitPumpManagerError.bolusMaxViolation
        case 0x20:
            return DanaKitPumpManagerError.unknown("bolusCommandError")
        case 0x40:
            return DanaKitPumpManagerError.unknown("Invalid bolus speed error")
        case 0x80:
            return DanaKitPumpManagerError.bolusInsulinLimitViolation
        default:
            return DanaKitPumpManagerError.unknown("Unknown error: \(code)")
        }
    }
}

public enum BolusSpeed: UInt8 {
    case speed12 = 0
    case speed30 = 1
    case speed60 = 2

    static func all() -> [Int] {
        [Int(BolusSpeed.speed12.rawValue), Int(BolusSpeed.speed30.rawValue), Int(BolusSpeed.speed60.rawValue)]
    }

    func format() -> String {
        switch self {
        case .speed12:
            return String(localized: "12 sec/U", comment: "Dana bolus speed 12u per min")
        case .speed30:
            return String(localized: "30 sec/U", comment: "Dana bolus speed 30u per min")
        case .speed60:
            return String(localized: "60 sec/U", comment: "Dana bolus speed 60u per min")
        }
    }
}
