import Foundation
import LoopKit

public enum PumpManagerAlert: Hashable, Codable {
    case batteryZeroPercent(_ raw: Data)
    case pumpError(_ raw: Data)
    case occlusion(_ raw: Data)
    case lowBattery(_ raw: Data)
    case shutdown(_ raw: Data)
    case basalCompare(_ raw: Data)
    case bloodSugarMeasure(_ raw: Data)
    case remainingInsulinLevel(_ raw: Data)
    case emptyReservoir(_ raw: Data)
    case checkShaft(_ raw: Data)
    case basalMax(_ raw: Data)
    case dailyMax(_ raw: Data)
    case bloodSugarCheckMiss(_ raw: Data)
    case ble5InvalidKeys(_ deviceName: String)
    case unknown(_ raw: Data?)

    var contentTitle: String {
        switch self {
        case .batteryZeroPercent:
            return String(localized: "Pump battery 0%", comment: "Alert title for batteryZeroPercent")
        case .pumpError:
            return String(localized: "Pump error", comment: "Alert title for pumpError")
        case .occlusion:
            return String(localized: "Occlusion", comment: "Alert title for occlusion")
        case .lowBattery:
            return String(localized: "Low pump battery", comment: "Alert title for lowBattery")
        case .shutdown:
            return String(localized: "Pump shutdown", comment: "Alert title for shutdown")
        case .basalCompare:
            return String(localized: "Basal Compare", comment: "Alert title for basalCompare")
        case .bloodSugarMeasure:
            return String(localized: "Blood glucose Measure", comment: "Alert title for bloodSugarMeasure")
        case .remainingInsulinLevel:
            return String(localized: "Remaining insulin level", comment: "Alert title for remainingInsulinLevel")
        case .emptyReservoir:
            return String(localized: "Empty reservoir", comment: "Alert title for emptyReservoir")
        case .checkShaft:
            return String(localized: "Check chaft", comment: "Alert title for checkShaft")
        case .basalMax:
            return String(localized: "Basal limit reached", comment: "Alert title for basalMax")
        case .dailyMax:
            return String(localized: "Daily limit reached", comment: "Alert title for dailyMax")
        case .bloodSugarCheckMiss:
            return String(localized: "Missed Blood glucose check", comment: "Alert title for bloodSugarCheckMiss")
        case .ble5InvalidKeys:
            return String(localized: "ERROR: Failed to pair device", comment: "Dana-i invalid ble5 keys")
        case .unknown:
            return String(localized: "Unknown error", comment: "Alert title for unknown")
        }
    }

    var contentBody: String {
        switch self {
        case .batteryZeroPercent:
            return String(localized: "Battery is empty. Replace it now!", comment: "Alert body for batteryZeroPercent")
        case .pumpError:
            return String(localized: "Check the pump and try again", comment: "Alert body for pumpError")
        case .occlusion:
            return String(localized: "Check the reservoir and infus and try again", comment: "Alert body for occlusion")
        case .lowBattery:
            return String(localized: "Pump battery needs to be replaced soon", comment: "Alert body for lowBattery")
        case .shutdown:
            return String(
                localized:
                "There has not been any interactions with the pump for too long. Either disable this function in the pump or interact with the pump",
                comment: "Alert body for shutdown"
            )
        case .basalCompare:
            return ""
        case .bloodSugarMeasure:
            return ""
        case .remainingInsulinLevel:
            return ""
        case .emptyReservoir:
            return String(localized: "Reservoir is empty. Replace it now!", comment: "Alert body for emptyReservoir")
        case .checkShaft:
            return String(
                localized:
                "The pump has detected an issue with its chaft. Please remove the reservoir, check everything and try again",
                comment: "Alert body for checkShaft"
            )
        case .basalMax:
            return String(
                localized:
                "Your daily basal limit has been reached. Please contact your Dana distributer to increase the limit",
                comment: "Alert body for basalMax"
            )
        case .dailyMax:
            return String(
                localized:
                "Your daily insulin limit has been reached. Please contact your Dana distributer to increase the limit",
                comment: "Alert body for dailyMax"
            )
        case .bloodSugarCheckMiss:
            return String(
                localized:
                "A blood glucose check reminder has been setup in your pump and is triggered. Please remove it or give your glucose level to the pump",
                comment: "Alert body for bloodSugarCheckMiss"
            )
        case let .ble5InvalidKeys(deviceName):
            return String(localized: "Failed to pair to ", comment: "Dana-i failed to pair p1") + deviceName + String(
                localized:
                ". Please go to your bluetooth settings, forget this device, and try again",
                comment: "Dana-i failed to pair p2"
            )
        case .unknown:
            return String(
                localized:
                "An unknown error has occurred during processing the alert from the pump. Please report this",
                comment: "Alert body for unknown"
            )
        }
    }

    public var identifier: String {
        switch self {
        case .batteryZeroPercent:
            return "batteryZeroPercent"
        case .pumpError:
            return "pumpError"
        case .occlusion:
            return "occlusion"
        case .lowBattery:
            return "lowBattery"
        case .shutdown:
            return "shutdown"
        case .basalCompare:
            return "basalCompare"
        case .bloodSugarMeasure:
            return "bloodSugarMeasure"
        case .remainingInsulinLevel:
            return "remainingInsulinLevel"
        case .emptyReservoir:
            return "emptyReservoir"
        case .checkShaft:
            return "checkShaft"
        case .basalMax:
            return "basalMax"
        case .dailyMax:
            return "dailyMax"
        case .bloodSugarCheckMiss:
            return "bloodSugarCheckMiss"
        case .ble5InvalidKeys:
            return "ble5InvalidKeys"
        case .unknown:
            return "unknown"
        }
    }

    var type: PumpAlarmType {
        switch self {
        case .batteryZeroPercent:
            return .noPower
        case .pumpError:
            return .other("pumpError")
        case .occlusion:
            return .occlusion
        case .lowBattery:
            return .lowPower
        case .shutdown:
            return .other("shutdown")
        case .basalCompare:
            return .other("basalCompare")
        case .bloodSugarMeasure:
            return .other("bloodSugarMeasure")
        case .remainingInsulinLevel:
            return .other("remainingInsulinLevel")
        case .emptyReservoir:
            return .noInsulin
        case .checkShaft:
            return .other("checkShaft")
        case .basalMax:
            return .other("basalMax")
        case .dailyMax:
            return .other("dailyMax")
        case .bloodSugarCheckMiss:
            return .other("bloodSugarCheckMiss")
        case .ble5InvalidKeys:
            return .other("ble5InvalidKeys")
        case .unknown:
            return .other("unknown")
        }
    }

    var raw: Data {
        switch self {
        case let .batteryZeroPercent(raw):
            return raw
        case let .pumpError(raw):
            return raw
        case let .occlusion(raw):
            return raw
        case let .lowBattery(raw):
            return raw
        case let .shutdown(raw):
            return raw
        case let .basalCompare(raw):
            return raw
        case let .bloodSugarMeasure(raw):
            return raw
        case let .remainingInsulinLevel(raw):
            return raw
        case let .emptyReservoir(raw):
            return raw
        case let .checkShaft(raw):
            return raw
        case let .basalMax(raw):
            return raw
        case let .dailyMax(raw):
            return raw
        case let .bloodSugarCheckMiss(raw):
            return raw
        case .ble5InvalidKeys:
            return Data()
        case let .unknown(raw):
            return raw ?? Data()
        }
    }

    var actionButtonLabel: String {
        String(localized: "Okay", comment: "Ok")
    }

    var foregroundContent: Alert.Content {
        Alert.Content(title: contentTitle, body: contentBody, acknowledgeActionButtonLabel: actionButtonLabel)
    }

    var backgroundContent: Alert.Content {
        Alert.Content(title: contentTitle, body: contentBody, acknowledgeActionButtonLabel: actionButtonLabel)
    }
}
