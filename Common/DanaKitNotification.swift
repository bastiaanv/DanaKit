import Foundation
import LoopKit

enum DanaKitNotification {
    case disconnectedReminder(after: TimeInterval)
    case disconnectWarning

    var alert: Alert {
        let content = alertContent
        return Alert(
            identifier: identifier,
            foregroundContent: content,
            backgroundContent: content,
            trigger: trigger,
        )
    }

    private static let managerIdentifier = "Medtrum"
    var identifier: Alert.Identifier {
        switch self {
        case .disconnectedReminder:
            return Alert.Identifier(
                managerIdentifier: Self.managerIdentifier,
                alertIdentifier: "com.bastiaanv.continuous-ble.disconnect-reminder"
            )
        case .disconnectWarning:
            return Alert.Identifier(
                managerIdentifier: Self.managerIdentifier,
                alertIdentifier: "com.bastiaanv.continuous-ble.disconnect-warning"
            )
        }
    }

    private var alertContent: Alert.Content {
        switch self {
        case .disconnectedReminder:
            return Alert.Content(
                title: String(localized: "Pump is still disconnected", comment: "Title disconnect reminder notification"),
                body: String(
                    localized: "Your pump is still disconnected after the set period!",
                    comment: "Body disconnect reminder notification"
                ),
                acknowledgeActionButtonLabel: String(localized: "OK", comment: "Acknoledge alert"),
            )
        case .disconnectWarning:
            return Alert.Content(
                title: String(localized: "Pump is disconnected", comment: "Title disconnect warning notification"),
                body: String(
                    localized: "Your pump is disconnected longer than 5 minutes!",
                    comment: "Body disconnect warning notification"
                ),
                acknowledgeActionButtonLabel: String(localized: "OK", comment: "Acknoledge alert"),
            )
        }
    }

    private var trigger: Alert.Trigger {
        switch self {
        case let .disconnectedReminder(after):
            return Alert.Trigger.delayed(interval: after)
        default:
            return Alert.Trigger.immediate
        }
    }
}
