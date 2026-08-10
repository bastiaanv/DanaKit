import Foundation
import LoopKit

public class UnfinalizedDose : NSObject {
    public typealias RawValue = [String: Any]

    public let type: DoseType
    public let startDate: Date
    public let expectedEndDate: Date
    public let value: Double
    public var deliveredUnits: Double = 0
    public let insulinType: InsulinType?
    public let automatic: Bool?

    public convenience init(units: Double, duration: TimeInterval, activationType: BolusActivationType, insulinType: InsulinType?) {
        self.init(
            type: .bolus,
            startDate: Date.now,
            expectedEndDate: Date.now.addingTimeInterval(duration),
            value: units,
            deliveredUnits: 0,
            insulinType: insulinType,
            automatic: activationType.isAutomatic
        )
    }

    init(
        type: DoseType,
        startDate: Date,
        expectedEndDate: Date,
        value: Double,
        deliveredUnits: Double,
        insulinType: InsulinType?,
        automatic: Bool?
    ) {
        self.type = type
        self.startDate = startDate
        self.expectedEndDate = expectedEndDate
        self.value = value
        self.deliveredUnits = deliveredUnits
        self.insulinType = insulinType
        self.automatic = automatic
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
            deliveredUnits: nil,
            insulinType: insulinType,
            automatic: automatic,
            isMutable: true
        )
    }
    
    public required convenience init?(rawValue: RawValue) {
        guard let typeRawValue = rawValue["type"] as? DoseType.RawValue,
              let type = DoseType(rawValue: typeRawValue),
              let startDate = rawValue["startDate"] as? Date,
              let expectedEndDate = rawValue["expectedEndDate"] as? Date,
              let value = rawValue["value"] as? Double
        else {
            return nil
        }

        let deliveredUnits = rawValue["deliveredUnits"] as? Double ?? 0
        let insulinType = (rawValue["insulinType"] as? InsulinType.RawValue).flatMap { InsulinType(rawValue: $0) }
        let automatic = rawValue["automatic"] as? Bool

        self.init(
            type: type,
            startDate: startDate,
            expectedEndDate: expectedEndDate,
            value: value,
            deliveredUnits: deliveredUnits,
            insulinType: insulinType,
            automatic: automatic
        )
    }

    public var rawValue: RawValue {
        [
            "type": type.rawValue,
            "startDate": startDate,
            "expectedEndDate": expectedEndDate,
            "value": value,
            "deliveredUnits": deliveredUnits,
            "insulinType": insulinType?.rawValue as Any,
            "automatic": automatic as Any
        ]
    }
}
