import Foundation
import LoopKit

public class UnfinalizedDose: NSObject {
    public typealias RawValue = [String: Any]

    public let type: DoseType
    public let startDate: Date
    public let expectedEndDate: Date
    public let value: Double
    public var deliveredUnits: Double = 0
    public let insulinType: InsulinType?
    public let automatic: Bool?

    public convenience init(
        units: Double,
        duration: TimeInterval,
        activationType: BolusActivationType,
        insulinType: InsulinType?
    ) {
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
    
    public convenience init(resumeStartTime: Date, insulinType: InsulinType?) {
        self.init(
            type: .resume,
            startDate: resumeStartTime,
            expectedEndDate: resumeStartTime,
            value: 0,
            deliveredUnits: 0,
            insulinType: insulinType,
            automatic: false
        )
    }
    
    public convenience init(suspendStartTime: Date) {
        self.init(
            type: .suspend,
            startDate: suspendStartTime,
            expectedEndDate: suspendStartTime,
            value: 0,
            deliveredUnits: 0,
            insulinType: nil,
            automatic: false
        )
    }
    
    public convenience init(basalRate: Double, insulinType: InsulinType?, startDate: Date = Date.now) {
        self.init(
            type: .basal,
            startDate: startDate,
            expectedEndDate: startDate,
            value: basalRate,
            deliveredUnits: 0,
            insulinType: insulinType,
            automatic: false
        )
    }
    
    public convenience init(tempRate: Double, duration: TimeInterval, insulinType: InsulinType?, automatic: Bool, startDate: Date = Date.now) {
        self.init(
            type: .tempBasal,
            startDate: startDate,
            expectedEndDate: startDate.addingTimeInterval(duration),
            value: tempRate,
            deliveredUnits: 0,
            insulinType: insulinType,
            automatic: automatic
        )
    }

    private init(
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
        let isMutable = endDate == nil

        switch type {
        case .bolus:
            var endDate = endDate ?? expectedEndDate
            if endDate > Date.now {
                // The endDate of a bolus cannot be in the future...
                endDate = Date.now
            }

            return DoseEntry(
                type: .bolus,
                startDate: startDate,
                endDate: endDate,
                value: value,
                unit: .units,
                deliveredUnits: isMutable ? nil : deliveredUnits,
                insulinType: insulinType,
                automatic: automatic,
                isMutable: isMutable
            )

        case .basal:
            return DoseEntry(
                type: .basal,
                startDate: startDate,
                value: roundBasalRate(value),
                unit: .unitsPerHour,
                insulinType: insulinType
            )

        case .tempBasal:
            let actualEndDate: Date
            if let endDate {
                // in case this finalization happens late (TBR ended while not connected to the phone, etc)
               // don't report the end date later than the scheduled end date
                actualEndDate = min(endDate, expectedEndDate)
            } else {
                actualEndDate = expectedEndDate
            }
                 
            let duration = actualEndDate.timeIntervalSince(startDate)
            return DoseEntry(
                type: .tempBasal,
                startDate: startDate,
                endDate: actualEndDate,
                value: value,
                unit: .unitsPerHour,
                deliveredUnits: isMutable ? nil : roundBasalRate(value * (duration / .hours(1))),
                insulinType: insulinType,
                automatic: automatic,
                isMutable: isMutable
            )

        case .suspend:
            return DoseEntry(
                suspendDate: startDate,
                automatic: automatic
            )

        case .resume:
            return DoseEntry(
                resumeDate: startDate,
                insulinType: insulinType,
                automatic: automatic
            )
        }
    }
    
    private func roundBasalRate(_ rate: Double) -> Double {
        DanaKitPumpManager.onboardingSupportedBasalRates.last(where: { $0 <= rate }) ?? 0
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
