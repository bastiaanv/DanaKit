public enum DanaKitPumpManagerError {
    case noConnection(_ result: ConnectionResult)
    case pumpSuspended
    case pumpIsBusy
    case failedTempBasalAdjustment(_ extraMessage: String)
    case failedSuspensionAdjustment
    case failedBasalGeneration
    case failedBasalAdjustment
    case failedTimeAdjustment
    case unsupportedTempBasal(_ duration: TimeInterval)
    case bolusTimeoutActive
    case bolusMaxViolation
    case bolusInsulinLimitViolation
    case unknown(_ message: String)
}

extension DanaKitPumpManagerError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .noConnection(result):
            return String(localized:
                "Failed to make a connection: ",
                comment: "Error description when no dana pump connected"
            ) + connectionDescription(result)
        case let .failedTempBasalAdjustment(reason):
            return String(localized: 
                "Failed to adjust temp basal. \(reason)",
                comment: "Error description when failed temp adjustment"
            )
        case .failedSuspensionAdjustment:
            return String(localized: "Failed to adjust suspension", comment: "Error description when failed suspension adjustment")
        case .failedBasalGeneration:
            return String(localized: 
                "Failed to generate Dana basal program",
                comment: "Error description when failed generating basal program"
            )
        case .failedBasalAdjustment:
            return String(localized: "Failed to adjust basal", comment: "Error description when failed basal adjustment")
        case let .unsupportedTempBasal(duration):
            return String(
                format: String(localized:
                    "Setting temp basal is not supported at this time. Duration: %lld sec",
                    comment: "Error description when trying to set temp basal"
                ),
                duration
            )
        case .pumpSuspended:
            return String(localized: 
                "The insulin delivery has been suspend. Action failed",
                comment: "Error description when pump is suspended"
            )
        case .failedTimeAdjustment:
            return String(localized: "Failed to adjust pump time", comment: "Error description when pump time failed to sync")
        case .pumpIsBusy:
            return String(localized: 
                "Action has been canceled, because the pump is busy",
                comment: "Error description when pump is busy (with bolussing probably)"
            )
        case .bolusTimeoutActive:
            return String(localized: 
                "A bolus timeout is active. The loop cycle cannot be completed till the timeout is inactive",
                comment: "Error description when pump has an active blockage"
            )
        case .bolusMaxViolation:
            return String(localized: 
                "The max bolus limit is reached. Please try a lower amount or increase the limit",
                comment: "Error description when pump has reached the bolus max"
            )
        case .bolusInsulinLimitViolation:
            return String(localized: 
                "The max daily insulin limit is reached. Please try a lower amount or increase the limit",
                comment: "Error description when pump has reached the daily max"
            )
        case let .unknown(message):
            return "Unknown error occured: \(message)"
        }
    }

    private func connectionDescription(_ result: ConnectionResult) -> String {
        switch result {
        case .success:
            return "Connected"
        case let .failure(error):
            return "Failure: \(error)"
        case .invalidBle5Keys:
            return "Invalid BLE5 keys"
        case .requestedPincode:
            return "Requested PIN"
        case .timeout:
            return "Timeout was hit"
        case .alreadyConnectedAndBusy:
            return "Is already connected and is busy"
        }
    }
}
