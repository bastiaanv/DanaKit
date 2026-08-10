@testable import DanaKit
import XCTest

/// Tests covering the dose-accounting behaviors called out in PumpManagerDoseReporting.md §11:
/// idempotency / stable identity, cancel-vs-full (identity never changes), rounding, and the
/// persist-the-in-progress-dose requirement. These exercise the pure, deterministic dose logic in
/// `UnfinalizedDose`, the `NewPumpEvent`/`DoseEntry` convenience builders, and state persistence.
class DoseReportingTests: XCTestCase {

    // MARK: - Mutable dose lifecycle (§3)

    func testInProgressBolusIsMutableAndHasNoDeliveredAmount() {
        let dose = UnfinalizedDose(
            units: 2.0,
            duration: 3600,
            activationType: .manualNoRecommendation,
            insulinType: nil
        )
        let entry = dose.toDoseEntry(endDate: nil)

        XCTAssertTrue(entry.isMutable, "An in-progress bolus must still report isMutable == true")
        XCTAssertEqual(entry.type, .bolus)
        XCTAssertEqual(entry.programmedUnits, 2.0, accuracy: 0.001)
        XCTAssertNil(entry.deliveredUnits, "An in-progress bolus must not report a delivered amount")
        XCTAssertEqual(entry.endDate, dose.expectedEndDate, accuracy: 1)
    }

    func testFinalizedBolusIsImmutableWithDeliveredUnits() {
        let dose = UnfinalizedDose(
            units: 2.0,
            duration: 3600,
            activationType: .manualNoRecommendation,
            insulinType: nil
        )
        dose.deliveredUnits = 1.25 // partial delivery, e.g. after a cancel
        let end = dose.startDate.addingTimeInterval(15)
        let entry = dose.toDoseEntry(endDate: end)

        XCTAssertFalse(entry.isMutable, "A finalized bolus must no longer be mutable")
        XCTAssertEqual(entry.programmedUnits, 2.0, accuracy: 0.001, "value must carry the programmed amount")
        XCTAssertEqual(entry.deliveredUnits, 1.25, accuracy: 0.001, "deliveredUnits must carry the actual amount")
        XCTAssertEqual(entry.endDate, end)
    }

    // MARK: - Idempotency / stable identity (§4, §11 "cancel everything")

    func testBolusSyncIdentifierStableThroughCancellation() {
        let dose = UnfinalizedDose(
            units: 2.0,
            duration: 120,
            activationType: .manualNoRecommendation,
            insulinType: nil
        )

        let mutableEvent = NewPumpEvent.bolus(dose: dose.toDoseEntry(endDate: nil), date: dose.startDate)

        // Simulate cancellation: partial delivery, finalized earlier than scheduled.
        dose.deliveredUnits = 0.75
        let canceledEvent = NewPumpEvent.bolus(
            dose: dose.toDoseEntry(endDate: dose.startDate.addingTimeInterval(15)),
            date: dose.startDate
        )

        XCTAssertEqual(
            mutableEvent.dose?.syncIdentifier,
            canceledEvent.dose?.syncIdentifier,
            "The bolus identity must never change when the dose is canceled/finalized"
        )
    }

    func testBolusSyncIdentifierIndependentOfDeliveredAmount() {
        let dose = UnfinalizedDose(
            units: 2.0,
            duration: 120,
            activationType: .manualNoRecommendation,
            insulinType: nil
        )

        dose.deliveredUnits = 0.0
        let partialEvent = NewPumpEvent.bolus(
            dose: dose.toDoseEntry(endDate: dose.startDate.addingTimeInterval(5)),
            date: dose.startDate
        )

        dose.deliveredUnits = 2.0
        let fullEvent = NewPumpEvent.bolus(
            dose: dose.toDoseEntry(endDate: dose.expectedEndDate),
            date: dose.startDate
        )

        XCTAssertEqual(
            partialEvent.dose?.syncIdentifier,
            fullEvent.dose?.syncIdentifier,
            "The identity must be derived from programmed amount + start time, not the delivered amount"
        )
    }

    func testDistinctBolusesHaveDistinctIdentifiers() {
        let t0 = Date()
        let doseA = DoseEntry.bolus(
            units: 1.0,
            deliveredUnits: 1.0,
            duration: 60,
            activationType: .manualNoRecommendation,
            insulinType: nil,
            startDate: t0
        )
        let doseB = DoseEntry.bolus(
            units: 1.0,
            deliveredUnits: 1.0,
            duration: 60,
            activationType: .manualNoRecommendation,
            insulinType: nil,
            startDate: t0.addingTimeInterval(120)
        )

        let eventA = NewPumpEvent.bolus(dose: doseA, date: doseA.startDate)
        let eventB = NewPumpEvent.bolus(dose: doseB, date: doseB.startDate)

        XCTAssertNotEqual(
            eventA.dose?.syncIdentifier,
            eventB.dose?.syncIdentifier,
            "Two different boluses (different start times) must not share an identity"
        )
    }

    // MARK: - Temp basal (§3/§4)

    func testTempBasalIdentityStableAcrossFinalization() {
        let start = Date()
        let running = DoseEntry.tempBasal(
            absoluteUnit: 1.0,
            duration: 3600,
            insulinType: nil,
            startDate: start
        )
        let finalized = DoseEntry.tempBasal(
            absoluteUnit: 1.0,
            duration: 3600,
            insulinType: nil,
            startDate: start,
            endDate: start.addingTimeInterval(3600)
        )

        XCTAssertTrue(running.isMutable)
        XCTAssertNil(running.deliveredUnits)
        XCTAssertFalse(finalized.isMutable)

        let runningEvent = NewPumpEvent.tempBasal(dose: running, date: start)
        let finalizedEvent = NewPumpEvent.tempBasal(dose: finalized, date: start)

        // A running TBR re-reported as finalized (natural end) must keep the same identity so Loop
        // updates it rather than creating a duplicate.
        XCTAssertEqual(runningEvent.dose?.syncIdentifier, finalizedEvent.dose?.syncIdentifier)
    }

    // MARK: - Rounding (§9, §11)

    func testTempBasalDeliveredUnitsRoundedToPumpIncrement() {
        let start = Date()
        let finalized = DoseEntry.tempBasal(
            absoluteUnit: 0.55,
            duration: 3600,
            insulinType: nil,
            startDate: start,
            endDate: start.addingTimeInterval(1800) // 0.5 h -> 0.55 * 0.5 = 0.275 U
        )

        // Rounded down to the pump's 0.01 U/hr supported increment.
        XCTAssertEqual(finalized.deliveredUnits ?? 0, 0.27, accuracy: 0.0001)
    }

    // MARK: - State persistence of an in-progress dose (§10, §11 "interrupt everything")

    func testStatePersistsPendingDoseAcrossReconstruction() {
        let state = DanaKitPumpManagerState(basalSchedule: nil)
        let dose = UnfinalizedDose(
            units: 3.0,
            duration: 3600,
            activationType: .manualNoRecommendation,
            insulinType: nil
        )
        dose.deliveredUnits = 1.5
        state.unfinalizedDose = dose
        state.loopInitiatedBolusStartDates = [Date(), Date().addingTimeInterval(-10)]

        let restored = DanaKitPumpManagerState(rawValue: state.rawValue)

        let restoredDose = restored.unfinalizedDose
        XCTAssertNotNil(restoredDose, "A pending in-progress dose must survive a raw-state round trip")
        XCTAssertEqual(restoredDose?.value, 3.0, accuracy: 0.001)
        XCTAssertEqual(restoredDose?.deliveredUnits, 1.5, accuracy: 0.001)
        XCTAssertEqual(restoredDose?.startDate, dose.startDate)
        XCTAssertEqual(restoredDose?.expectedEndDate, dose.expectedEndDate)
        XCTAssertEqual(restored.loopInitiatedBolusStartDates.count, 2)
    }

    func testStateClearingPendingDoseDoesNotLeaveStaleDose() {
        let state = DanaKitPumpManagerState(basalSchedule: nil)
        state.unfinalizedDose = UnfinalizedDose(
            units: 1.0,
            duration: 60,
            activationType: .manualNoRecommendation,
            insulinType: nil
        )
        state.unfinalizedDose = nil

        let restored = DanaKitPumpManagerState(rawValue: state.rawValue)
        XCTAssertNil(restored.unfinalizedDose, "Clearing the pending dose must persist as nil")
    }
}
