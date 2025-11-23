import Foundation
import LoopKit

public class UnfinalizedDose {
    public typealias RawValue = [String: Any]

    public let type: DoseType
    public let startDate: Date
    public let expectedEndDate: Date
    public let unit: DoseUnit
    public let value: Double
    public var deliveredUnits: Double = 0
    public let insulinType: InsulinType?
    public let automatic: Bool?

    public init(units: Double, duration: TimeInterval, activationType: BolusActivationType, insulinType: InsulinType?) {
        type = .bolus
        unit = .units
        value = units
        startDate = Date.now
        expectedEndDate = Date.now.addingTimeInterval(duration)
        self.insulinType = insulinType
        automatic = activationType.isAutomatic
    }

    public func toDoseEntry(endDate: Date?) -> DoseEntry {
        if let endDate = endDate {
            return DoseEntry(
                type: .bolus,
                startDate: startDate,
                endDate: endDate,
                value: value,
                unit: .units,
                deliveredUnits: deliveredUnits,
                insulinType: insulinType,
                automatic: automatic,
                isMutable: false
            )
        }

        return DoseEntry(
            type: .bolus,
            startDate: startDate,
            endDate: expectedEndDate,
            value: value,
            unit: .units,
            deliveredUnits: value,
            insulinType: insulinType,
            automatic: automatic,
            isMutable: true
        )
    }
}
