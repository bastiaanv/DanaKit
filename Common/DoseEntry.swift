import Foundation
import LoopKit

public extension DoseEntry {
    static func bolus(
        units: Double,
        deliveredUnits: Double,
        duration: TimeInterval,
        activationType: BolusActivationType,
        insulinType: InsulinType?,
        startDate: Date = Date.now
    ) -> DoseEntry {
        var endTime = Date.now
        endTime.addTimeInterval(duration)

        return DoseEntry(
            type: .bolus,
            startDate: startDate,
            endDate: endTime,
            value: units,
            unit: .units,
            deliveredUnits: deliveredUnits,
            insulinType: insulinType,
            automatic: activationType.isAutomatic,
            manuallyEntered: activationType == .manualNoRecommendation,
            isMutable: false
        )
    }

    static func tempBasal(
        absoluteUnit: Double,
        duration: TimeInterval,
        insulinType: InsulinType?,
        startDate: Date = Date.now,
        endDate: Date? = nil
    ) -> DoseEntry {
        if let endDate = endDate {
            let duration = endDate.timeIntervalSince(startDate)
            return DoseEntry(
                type: .tempBasal,
                startDate: startDate,
                endDate: endDate,
                value: absoluteUnit,
                unit: .unitsPerHour,
                deliveredUnits: roundBasalRate(absoluteUnit * (duration / .hours(1))),
                insulinType: insulinType,
                automatic: true,
                isMutable: false
            )
        }

        return DoseEntry(
            type: .tempBasal,
            startDate: startDate,
            endDate: startDate + duration,
            value: absoluteUnit,
            unit: .unitsPerHour,
            insulinType: insulinType,
            automatic: true,
            isMutable: true
        )
    }

    static func basal(rate: Double, insulinType: InsulinType?, startDate: Date = Date.now) -> DoseEntry {
        DoseEntry(
            type: .basal,
            startDate: startDate,
            value: rate,
            unit: .unitsPerHour,
            insulinType: insulinType
        )
    }

    static func resume(insulinType: InsulinType?, resumeDate: Date = Date.now) -> DoseEntry {
        DoseEntry(
            resumeDate: resumeDate,
            insulinType: insulinType
        )
    }

    static func suspend(suspendDate: Date = Date.now) -> DoseEntry {
        DoseEntry(suspendDate: suspendDate)
    }
    
    private static func roundBasalRate(_ rate: Double) -> Double {
        DanaKitPumpManager.onboardingSupportedBasalRates.last(where: { $0 <= rate }) ?? 0
    }
}
