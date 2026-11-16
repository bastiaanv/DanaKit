struct PacketBolusStart {
    enum BolusCommandType: UInt8 {
        case normal = 0
        case algorithm = 1
    }
    
    var amount: Double
    var speed: BolusSpeed
    
    // Dana-i2 only
    var commandType: BolusCommandType?
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

        var data = Data([
            UInt8(bolusRate & 0xFF),
            UInt8((bolusRate >> 8) & 0xFF),
            options.speed.rawValue
        ])

        // Dana-i2 does not answer the 3 byte request. It needs the command type as the 4th byte
        if let commandType = options.commandType {
            data.append(commandType.rawValue)
        }

        return data
    }

    func parse(data: Data, usingUtc _: Bool?) -> any DanaParsePacketProtocol {
        DanaParsePacket<String>(success: errorCode(data) == 0, rawData: data, data: nil)
    }

    func transformBolusError(data: Data) -> DanaKitPumpManagerError {
        let code = errorCode(data)
        return options.commandType != nil ? transformDanaI2BolusError(code: code) : transformBolusError(code: UInt8(code))
    }

    /**
     * Dana-i2 answers with 2 bytes of error flags, older pumps with 1 byte.
     * Reading only 1 byte on Dana-i2 would take Bolus Max (0x0100) or Remain < Bolus (0x0200) as OK
     */
    private func errorCode(_ data: Data) -> UInt16 {
        guard options.commandType != nil, data.count >= DataStart + 2 else {
            return UInt16(data[DataStart])
        }

        return data.uint16(at: DataStart)
    }

    /**
     * Dana-i2 error flags. More than one flag can be set, then the first one in this list is used
     * 0x0001 => Pump suspended
     * 0x0002 => Daily max violation
     * 0x0004 => Bolus timeout active
     * 0x0008 => Pump busy
     * 0x0010 => No prime done
     * 0x0020 => Command error
     * 0x0040 => Speed error
     * 0x0080 => Insulin limit violation
     * 0x0100 => Max bolus violation
     * 0x0200 => Not enough insulin in reservoir
     * 0x0400 => Easy mode sleep
     */
    private func transformDanaI2BolusError(code: UInt16) -> DanaKitPumpManagerError {
        if code & 0x0001 != 0 {
            return DanaKitPumpManagerError.pumpSuspended
        } else if code & 0x0002 != 0 {
            return DanaKitPumpManagerError.bolusInsulinLimitViolation
        } else if code & 0x0004 != 0 {
            return DanaKitPumpManagerError.bolusTimeoutActive
        } else if code & 0x0008 != 0 {
            return DanaKitPumpManagerError.pumpIsBusy
        } else if code & 0x0010 != 0 {
            return DanaKitPumpManagerError.unknown("No prime done")
        } else if code & 0x0020 != 0 {
            return DanaKitPumpManagerError.unknown("bolusCommandError")
        } else if code & 0x0040 != 0 {
            return DanaKitPumpManagerError.unknown("Invalid bolus speed error")
        } else if code & 0x0080 != 0 {
            return DanaKitPumpManagerError.bolusInsulinLimitViolation
        } else if code & 0x0100 != 0 {
            return DanaKitPumpManagerError.bolusMaxViolation
        } else if code & 0x0200 != 0 {
            return DanaKitPumpManagerError.unknown("Not enough insulin in reservoir")
        } else if code & 0x0400 != 0 {
            return DanaKitPumpManagerError.unknown("Easy mode sleep active")
        }

        return DanaKitPumpManagerError.unknown("Unknown error: \(String(format: "0x%04X", code))")
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
    private func transformBolusError(code: UInt8) -> DanaKitPumpManagerError {
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
