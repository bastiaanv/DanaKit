import CoreBluetooth
import HealthKit
import LoopKit
import UIKit
import UserNotifications

public protocol StateObserver: AnyObject {
    func stateDidUpdate(_ state: DanaKitPumpManagerState, _ oldState: DanaKitPumpManagerState)
    func deviceScanDidUpdate(_ device: DanaPumpScan)
}

public class DanaKitPumpManager: DeviceManager {
    private(set) var bluetooth: BluetoothManager

    private var oldState: DanaKitPumpManagerState
    public var state: DanaKitPumpManagerState
    public var rawState: PumpManager.RawStateValue {
        state.rawValue
    }

    public static let pluginIdentifier: String = "Dana" // use a single token to make parsing log files easier
    public let managerIdentifier: String = "Dana"

    public var localizedTitle: String {
        state.getFriendlyDeviceName()
    }

    init(state: DanaKitPumpManagerState, dateGenerator _: @escaping () -> Date = Date.init) {
        self.state = state
        oldState = DanaKitPumpManagerState(rawValue: state.rawValue)
        DanaKitEncryption.setEnhancedEncryption(state.encryptionMode)

        bluetooth = self.state.isUsingContinuousMode ? ContinousBluetoothManager() : InteractiveBluetoothManager()
        bluetooth.pumpManager = self

        let nc = NotificationCenter.default
        nc.addObserver(
            self,
            selector: #selector(appMovedToBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        nc.addObserver(
            self,
            selector: #selector(appMovedToForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )

        // Rehydrate an in-progress bolus that survived an app restart so its IOB is not lost and it
        // can be reconciled against pump history on the next sync
        if let pending = state.bolusDose {
            if pending.expectedEndDate > Date.now {
                doseReporter = DanaKitDoseProgressReporter(total: pending.value)
            }
            // Clear the persisted in-progress flag so continuous-mode syncing is not blocked; the
            // pending dose remains and is finalized against pump history on the next sync.
            self.state.bolusState = .noBolus
        }
    }

    public required convenience init?(rawState: PumpManager.RawStateValue) {
        self.init(state: DanaKitPumpManagerState(rawValue: rawState))
    }

    let log = DanaLogger(category: "DanaKitPumpManager")
    public let pumpDelegate = WeakSynchronizedDelegate<PumpManagerDelegate>()

    private let statusObservers = WeakSynchronizedSet<PumpManagerStatusObserver>()
    private let stateObservers = WeakSynchronizedSet<StateObserver>()
    private let scanDeviceObservers = WeakSynchronizedSet<StateObserver>()

    private var isPriming = false
    var doseReporter: DanaKitDoseProgressReporter?
    private var lastReportedBolusStep: Int = 0

    public var isOnboarded: Bool {
        state.isOnBoarded
    }

    public var isBluetoothConnected: Bool {
        bluetooth.isConnected
    }

    public var status: PumpManagerStatus {
        self.status(state)
    }

    public var debugDescription: String {
        let lines = [
            "## DanaKitPumpManager",
            state.debugDescription
        ]
        return lines.joined(separator: "\n")
    }

    public func disconnect(_ force: Bool = false) {
        guard bluetooth.isConnected else {
            // Disconnect is not needed
            return
        }

        bluetooth.disconnect(bluetooth.peripheral!, force: force)
    }

    public func disconnect(_ peripheral: CBPeripheral, _ force: Bool = false) {
        bluetooth.disconnect(peripheral, force: force)
        state.resetState()
    }

    public func startScan() throws {
        try bluetooth.startScan()
    }

    public func stopScan() {
        bluetooth.stopScan()
    }

    public func connect(_ peripheral: CBPeripheral, _ completion: @escaping (ConnectionResult) -> Void) {
        bluetooth.connect(peripheral, completion)
    }

    func finishV3Pairing(_ pairingKey: Data, _ randomPairingKey: Data) throws {
        try bluetooth.finishV3Pairing(pairingKey, randomPairingKey)
    }

    // Not persisted
    var provideHeartbeat: Bool = false

    private var lastHeartbeat: Date = .distantPast

    public func setMustProvideBLEHeartbeat(_ mustProvideBLEHeartbeat: Bool) {
        provideHeartbeat = mustProvideBLEHeartbeat
    }

    func issueHeartbeatIfNeeded() {
        if provideHeartbeat, Date().timeIntervalSince(lastHeartbeat) > 2 * 60 {
            pumpDelegate.notify { delegate in
                guard let delegate = delegate else {
                    self.log.error("Heartbeat fire could not be reported -> Missing delegate")
                    return
                }

                delegate.pumpManagerBLEHeartbeatDidFire(self)
            }
            lastHeartbeat = Date()
        }
    }

    public func toggleBluetoothMode() {
        state.isUsingContinuousMode = !state.isUsingContinuousMode

        bluetooth = state.isUsingContinuousMode ? ContinousBluetoothManager() : InteractiveBluetoothManager()
        bluetooth.pumpManager = self

        notifyStateDidChange()
    }

    public func reconnect(_ callback: @escaping (Bool) -> Void) {
        if let bluetoothManager = bluetooth as? ContinousBluetoothManager {
            bluetoothManager.reconnect { result in
                callback(result)
            }
        } else {
            log
                .error(
                    "Cannot reconnect in interactive mode, please use Coninuous mode for this or just the ensurePumpConnected function"
                )
            callback(false)
        }
    }

    private let backgroundTask = BackgroundTask()
    @objc func appMovedToBackground() {
        if state.useSilentTones {
            log.info("Starting silent tones")
            backgroundTask.startBackgroundTask()
        }
    }

    @objc func appMovedToForeground() {
        backgroundTask.stopBackgroundTask()
    }
}

extension DanaKitPumpManager: PumpManager {
    public static var onboardingMaximumBasalScheduleEntryCount: Int {
        24
    }

    public static var onboardingSupportedBasalRates: [Double] {
        // 0.01 units for rates between 0.00-3U/hr
        // 0 U/hr is a supported scheduled basal rate
        (0 ... 300).map { Double($0) / 100 }
    }

    public static var onboardingSupportedBolusVolumes: [Double] {
        // 0.05 units for rates between 0.05-30U
        // 0 is not a supported bolus volume
        (1 ... 600).map { Double($0) / 20 }
    }

    public static var onboardingSupportedMaximumBolusVolumes: [Double] {
        DanaKitPumpManager.onboardingSupportedBolusVolumes
    }

    public var delegateQueue: DispatchQueue! {
        get {
            pumpDelegate.queue
        }
        set {
            pumpDelegate.queue = newValue
        }
    }

    public var supportedBasalRates: [Double] {
        DanaKitPumpManager.onboardingSupportedBasalRates
    }

    public var supportedBolusVolumes: [Double] {
        DanaKitPumpManager.onboardingSupportedBolusVolumes
    }

    public var supportedMaximumBolusVolumes: [Double] {
        // 0.05 units for rates between 0.05-30U
        // 0 is not a supported bolus volume
        DanaKitPumpManager.onboardingSupportedBolusVolumes
    }

    public var maximumBasalScheduleEntryCount: Int {
        DanaKitPumpManager.onboardingMaximumBasalScheduleEntryCount
    }

    public var minimumBasalScheduleEntryDuration: TimeInterval {
        .hours(1)
    }

    public func roundToSupportedBolusVolume(units: Double) -> Double {
        // We do support rounding a 0 U volume to 0
        supportedBolusVolumes.last(where: { $0 <= units }) ?? 0
    }

    public func roundToSupportedBasalRate(unitsPerHour: Double) -> Double {
        supportedBasalRates.last(where: { $0 <= unitsPerHour }) ?? 0
    }

    public var pumpManagerDelegate: LoopKit.PumpManagerDelegate? {
        get {
            pumpDelegate.delegate
        }
        set {
            pumpDelegate.delegate = newValue
        }
    }

    public var pumpRecordsBasalProfileStartEvents: Bool {
        false
    }

    public var pumpReservoirCapacity: Double {
        300.0 // Dana-I & DanaRS have the same max reservoir capacity
    }

    public var lastSync: Date? {
        state.lastStatusDate
    }

    private func status(_ state: DanaKitPumpManagerState) -> LoopKit.PumpManagerStatus {
        // Check if temp basal is expired, before constructing basalDeliveryState
        PumpManagerStatus(
            timeZone: state.pumpTimeZone ?? TimeZone.current,
            device: device(),
            pumpBatteryChargeRemaining: state.batteryRemaining / 100,
            basalDeliveryState: state.basalDeliveryState,
            bolusState: bolusState(state.bolusState),
            insulinType: state.insulinType
        )
    }

    private func bolusState(_ bolusState: BolusState) -> PumpManagerStatus.BolusState {
        switch bolusState {
        case .noBolus:
            return .noBolus
        case .initiating:
            return .initiating
        case .canceling:
            return .canceling
        case .inProgress:
            if let dose = state.bolusDose?.toDoseEntry(endDate: nil) {
                return .inProgress(dose)
            }

            return .noBolus
        }
    }

    public func ensureCurrentPumpData(completion: ((Date?) -> Void)?) {
        guard Date.now.timeIntervalSince(state.lastStatusDate) > .minutes(4) else {
            log
                .warning(
                    "Skipping status update because pumpData is fresh: \(Date.now.timeIntervalSince(state.lastStatusDate)) sec"
                )
            completion?(state.lastStatusDate)
            return
        }

        if bluetooth as? ContinousBluetoothManager != nil, status.bolusState != .noBolus {
            log.warning("Skipping status update because bolus is running...")
            completion?(state.lastStatusDate)
            return
        }

        syncPump(completion)
    }

    public func createBolusProgressReporter(reportingOn _: DispatchQueue) -> DoseProgressReporter? {
        doseReporter
    }

    public func estimatedDuration(toBolus units: Double) -> TimeInterval {
        switch state.bolusSpeed {
        case .speed12:
            return units * 12 // 12sec/U
        case .speed30:
            return units * 30 // 30sec/U
        case .speed60:
            return units * 60 // 60sec/U
        }
    }

    public func enactBolus(
        units: Double,
        activationType: BolusActivationType,
        completion: @escaping (PumpManagerError?) -> Void
    ) {
        guard state.bolusState == .noBolus else {
            log.error("Pump already busy bolussing")
            completion(.deviceState(DanaKitPumpManagerError.pumpIsBusy))
            return
        }

        delegateQueue.async {
            let this = self
            let duration = self.estimatedDuration(toBolus: units)
            self.log.info("Enact bolus, units: \(units)U, duration: \(duration)sec")
            self.logDeviceCommunication("Enact bolus, units: \(units)U, duration: \(duration)sec", type: .delegate)

            self.state.bolusState = .initiating
            self.notifyStateDidChange()

            self.bluetooth.ensureConnected { result in
                switch result {
                case .success:
                    guard self.state.basalDeliveryOrdinal != .suspended else {
                        self.state.bolusState = .noBolus
                        self.doseReporter = nil
                        self.state.bolusDose = nil
                        self.notifyStateDidChange()
                        self.disconnect()

                        self.log.error("Pump is suspended")
                        completion(PumpManagerError.deviceState(DanaKitPumpManagerError.pumpSuspended))
                        return
                    }

                    do {
                        self.lastReportedBolusStep = 0
                        let packet =
                            generatePacketBolusStart(options: PacketBolusStart(
                                amount: units,
                                speed: !self.isPriming ? self.state.bolusSpeed : .speed12
                            ))
                        let result = try self.bluetooth.writeMessage(packet)

                        guard result.success else {
                            self.state.bolusState = .noBolus
                            self.doseReporter = nil
                            self.state.bolusDose = nil
                            self.notifyStateDidChange()
                            self.disconnect()

                            self.log.error("Pump rejected command. Data: \(result.rawData.base64EncodedString())")
                            completion(PumpManagerError.deviceState(transformBolusError(code: result.rawData[DataStart])))
                            return
                        }

                        // Sync the pump time
                        self.state.lastStatusPumpDateTime = self.fetchPumpTime() ?? Date.now
                        self.state.lastStatusDate = Date.now

                        let doseEntry = UnfinalizedDose(
                            units: units,
                            duration: duration,
                            activationType: activationType,
                            insulinType: self.state.insulinType
                        )

                        self.doseReporter = DanaKitDoseProgressReporter(total: units)

                        if !self.isPriming {
                            self.state.bolusDose = doseEntry
                            self.state.bolusState = .inProgress

                            let dose = doseEntry.toDoseEntry(endDate: nil)
                            self.pumpDelegate.notify { delegate in
                                guard let delegate = delegate else {
                                    this.log.error("Dose could not be reported -> Missing delegate")
                                    return
                                }

                                let event = NewPumpEvent.bolus(
                                    dose: dose,
                                    date: dose.startDate
                                )
                                delegate.pumpManager(
                                    this,
                                    hasNewPumpEvents: [event],
                                    lastReconciliation: this.state.lastStatusDate,
                                    replacePendingEvents: false,
                                ) { error in
                                    if let error = error {
                                        this.handlePumpDelegateError(method: "hasNewPumpEvents", error)
                                    }
                                }
                            }
                        }

                        self.log.info("Successfully started bolus!")
                        self.logDeviceCommunication("Successfully started bolus!", type: .delegateResponse)

                        self.notifyStateDidChange()
                        completion(nil)
                    } catch {
                        self.state.bolusState = .noBolus
                        self.doseReporter = nil
                        self.notifyStateDidChange()
                        self.disconnect()

                        self.log.error("Failed to do bolus. Error: \(error.localizedDescription)")
                        completion(PumpManagerError.connection(DanaKitPumpManagerError.unknown(error.localizedDescription)))
                    }
                default:
                    self.log.error("Connection error")
                    self.state.bolusState = .noBolus
                    self.doseReporter = nil
                    self.notifyStateDidChange()

                    completion(PumpManagerError.connection(DanaKitPumpManagerError.noConnection(result)))
                    return
                }
            }
        }
    }

    public func enactPrime(unit: Double, completion: @escaping (PumpManagerError?) -> Void) {
        isPriming = true
        enactBolus(units: unit, activationType: .manualNoRecommendation) { error in
            self.isPriming = false

            if let error = error {
                completion(error)
                return
            }

            completion(nil)
        }
    }

    public func cancelBolus(completion: @escaping (PumpManagerResult<DoseEntry?>) -> Void) {
        delegateQueue.async {
            self.log.info("Cancelling bolus...")
            self.logDeviceCommunication("Cancelling bolus...", type: .delegate)

            let oldBolusState = self.state.bolusState
            self.state.bolusState = .canceling
            self.notifyStateDidChange()

            // It is very likely that Loop is doing a bolus if the cancel action is triggerd
            // Therefore, we can reuse the connection and directly send the cancel command
            if self.bluetooth.isConnected, self.bluetooth.peripheral?.state == .connected {
                self.doCancelAction(oldBolusState: oldBolusState, completion: completion)
                return
            }

            self.bluetooth.ensureConnected { result in
                switch result {
                case .success:
                    self.doCancelAction(oldBolusState: oldBolusState, completion: completion)
                default:
                    self.state.bolusState = oldBolusState
                    self.notifyStateDidChange()

                    completion(.failure(PumpManagerError.connection(DanaKitPumpManagerError.noConnection(result))))
                    return
                }
            }
        }
    }

    private func doCancelAction(oldBolusState: BolusState, completion: @escaping (PumpManagerResult<DoseEntry?>) -> Void) {
        do {
            let packet = generatePacketBolusStop()
            let result = try bluetooth.writeMessage(packet)

            if !result.success {
                state.bolusState = oldBolusState
                notifyStateDidChange()

                completion(.failure(PumpManagerError.communication(nil)))
                return
            }

            let bolusCancelledAt = Date.now

            // Sync the pump time
            state.lastStatusPumpDateTime = fetchPumpTime() ?? Date.now
            state.lastStatusDate = Date.now

            disconnect()
            state.bolusState = .noBolus
            notifyStateDidChange()

            guard let doseEntry = state.bolusDose else {
                completion(.success(nil))
                return
            }

            log.info("Successfully cancelled bolus - \(doseEntry.deliveredUnits)U of \(doseEntry.value)U")
            logDeviceCommunication(
                "Successfully cancelled bolus - \(doseEntry.deliveredUnits)U of \(doseEntry.value)U",
                type: .delegateResponse
            )

            let dose = doseEntry.toDoseEntry(endDate: bolusCancelledAt)
            doseReporter = nil
            state.bolusDose = nil

            sendCancelEvent(dose)
            completion(.success(nil))
        } catch {
            state.bolusState = oldBolusState
            notifyStateDidChange()
            disconnect()

            log.error("Failed to cancel bolus. Error: \(error.localizedDescription)")
            completion(.failure(PumpManagerError.communication(DanaKitPumpManagerError.unknown(error.localizedDescription))))
        }
    }

    private func sendCancelEvent(_ dose: DoseEntry) {
        DispatchQueue.main.async {
            self.pumpDelegate.notify { delegate in
                guard let delegate = delegate else {
                    self.log.error("Dose could not be reported -> Missing delegate")
                    return
                }

                delegate.pumpManager(
                    self,
                    hasNewPumpEvents: [NewPumpEvent.bolus(dose: dose, date: dose.startDate)],
                    lastReconciliation: self.state.lastStatusDate,
                    replacePendingEvents: true,
                ) { error in
                    if let error = error {
                        self.handlePumpDelegateError(method: "hasNewPumpEvents", error)
                    }
                }
            }

            self.notifyStateDidChange()
        }
    }

    public func enactTempBasal(
        percentage: UInt16,
        for duration: TimeInterval,
        automatic: Bool,
        completion: @escaping (PumpManagerError?) -> Void
    ) {
        log.info("Enact manual temp basal. Value: \(percentage)%, duration: \(duration) sec")
        logDeviceCommunication(
            "Enact temp basal. Value: \(percentage)%, duration: \(duration) sec",
            type: .delegate
        )

        _enactTempBasal(percentage: percentage, for: duration, automatic: automatic, completion: completion)
    }

    public func enactTempBasal(
        unitsPerHour: Double,
        for duration: TimeInterval,
        completion: @escaping (PumpManagerError?) -> Void
    ) {
        log.info("Enact temp basal. Value: \(unitsPerHour) U/hr, duration: \(duration) sec")
        logDeviceCommunication(
            "Enact temp basal. Value: \(unitsPerHour) U/hr, duration: \(duration) sec",
            type: .delegate
        )

        guard let percentage = absoluteBasalRateToPercentage(
            absoluteValue: unitsPerHour,
            basalSchedule: state.basalSchedule
        ) else {
            disconnect()
            log.error("Basal schedule is not available...")
            completion(
                PumpManagerError
                    .configuration(
                        DanaKitPumpManagerError
                            .failedTempBasalAdjustment("Basal schedule is not available...")
                    )
            )
            return
        }

        _enactTempBasal(percentage: percentage, for: duration, automatic: true, completion: completion)
    }

    /// NOTE: There are 2 ways to set a temp basal:
    /// - The normal way (which only accepts full hours and percentages)
    /// - A short APS-special temp basal command (which only accepts 15 min or 30 min)
    /// Currently, this is implemented with a simpel U/hr -> % calculator
    /// NOTE: A temp basal >200% for 30 min (or full hour) is rescheduled to 15min
    private func _enactTempBasal(
        percentage: UInt16,
        for duration: TimeInterval,
        automatic: Bool,
        completion: @escaping (PumpManagerError?) -> Void
    ) {
        guard state.bolusState == .noBolus else {
            log.error("Rejecting command -> Pump is bolussing...")
            completion(.deviceState(DanaKitPumpManagerError.pumpIsBusy))
            return
        }

        delegateQueue.async {
            self.bluetooth.ensureConnected { result in
                switch result {
                case .success:
                    guard self.state.basalDeliveryOrdinal != .suspended else {
                        self.log.error("Pump is suspended")
                        self.disconnect()
                        completion(PumpManagerError.deviceState(DanaKitPumpManagerError.pumpSuspended))
                        return
                    }

                    do {
                        // Check if duration is supported
                        // If not, round it down to nearest supported duration
                        var duration = duration
                        if !self.isSupportedDuration(duration) {
                            let oldDuration = duration
                            if duration > .hours(1) {
                                // Round down to nearest full hour
                                duration = .hours(1) * floor(duration / .hours(1))
                                self.log
                                    .info(
                                        "Temp basal rounded down from \(oldDuration / .hours(1))h to \(floor(duration / .hours(1)))h"
                                    )

                            } else if duration > .minutes(30) {
                                // Round down to 30 min
                                duration = .minutes(30)
                                self.log.info("Temp basal rounded down from \(oldDuration / .minutes(1))min to 30min")

                            } else if duration > .minutes(15) {
                                // Round down to 15 min
                                duration = .minutes(15)
                                self.log.info("Temp basal rounded down from \(oldDuration / .minutes(1))min to 15min")

                            } else {
                                self.disconnect()
                                self.log.error("Temp basal below 15 min is unsupported (floor duration)")
                                completion(
                                    PumpManagerError
                                        .configuration(
                                            DanaKitPumpManagerError
                                                .failedTempBasalAdjustment(
                                                    "Temp basal below 15 min is unsupported... (floor duration)"
                                                )
                                        )
                                )
                                return
                            }
                        }

                        // Temp basal >15min && >200% is not supported
                        // Floor it down to 15min
                        if percentage > 200, duration != .minutes(15) {
                            duration = .minutes(15)
                        }

                        // The pump does not support temp basals over 500%
                        // Limiting the percentage and update the correct abosulute temp basal rate
                        var percentage = percentage
                        if percentage > 500 {
                            percentage = 500
                        }

                        if self.state.basalDeliveryOrdinal == .tempBasal {
                            let packet = generatePacketBasalCancelTemporary()
                            let result = try self.bluetooth.writeMessage(packet)

                            guard result.success else {
                                self.disconnect()
                                self.log.error("Could not cancel old temp basal")
                                completion(
                                    PumpManagerError
                                        .configuration(
                                            DanaKitPumpManagerError
                                                .failedTempBasalAdjustment("Could not cancel old temp basal")
                                        )
                                )
                                return
                            }

                            self.log.info("Successfully canceled old temp basal")
                        }

                        // 500% fix is already applied
                        let unitsPerHour = (Double(percentage) / 100) * self.state.getScheduledBasalRate()

                        if duration < .ulpOfOne {
                            // Temp basal is already canceled (if deem needed)
                            self.disconnect()

                            self.reportBasal(
                                unitsPerHour: unitsPerHour,
                                duration: duration,
                                percentage: percentage,
                                isTempBasal: false,
                                automatic: automatic
                            )

                            self.log.info("Successfully cancelled temp basal")
                            self.logDeviceCommunication("Successfully cancelled temp basal", type: .delegateResponse)
                            completion(nil)

                        } else if duration == .minutes(15) {
                            let packet =
                                generatePacketLoopSetTemporaryBasal(options: PacketLoopSetTemporaryBasal(
                                    percent: percentage,
                                    duration: .min15
                                ))
                            let result = try self.bluetooth.writeMessage(packet)
                            self.disconnect()

                            guard result.success else {
                                self.log.error("Pump rejected command (15 min)")
                                completion(
                                    PumpManagerError
                                        .configuration(
                                            DanaKitPumpManagerError
                                                .failedTempBasalAdjustment("Pump rejected command (15 min)")
                                        )
                                )
                                return
                            }

                            self.reportBasal(
                                unitsPerHour: unitsPerHour,
                                duration: duration,
                                percentage: percentage,
                                isTempBasal: true,
                                automatic: automatic
                            )

                            self.log.info("Successfully started 15 min temp basal")
                            self.logDeviceCommunication("Successfully started 15 min temp basal", type: .delegateResponse)
                            completion(nil)

                        } else if duration == .minutes(30) {
                            let packet =
                                generatePacketLoopSetTemporaryBasal(options: PacketLoopSetTemporaryBasal(
                                    percent: percentage,
                                    duration: .min30
                                ))
                            let result = try self.bluetooth.writeMessage(packet)
                            self.disconnect()

                            guard result.success else {
                                self.log.error("Pump rejected command (30 min)")
                                completion(
                                    PumpManagerError
                                        .configuration(
                                            DanaKitPumpManagerError
                                                .failedTempBasalAdjustment("Pump rejected command (30 min)")
                                        )
                                )
                                return
                            }

                            self.reportBasal(
                                unitsPerHour: unitsPerHour,
                                duration: duration,
                                percentage: percentage,
                                isTempBasal: true,
                                automatic: automatic
                            )

                            self.log.info("Successfully started 30 min temp basal")
                            self.logDeviceCommunication("Successfully started 30 min temp basal", type: .delegateResponse)

                            completion(nil)

                        } else {
                            // Full hour
                            let durationInHours = UInt8(floor(duration / .hours(1)))
                            let packet =
                                generatePacketBasalSetTemporary(
                                    options: PacketBasalSetTemporary(
                                        temporaryBasalRatio: UInt8(percentage),
                                        temporaryBasalDuration: durationInHours
                                    )
                                )
                            let result = try self.bluetooth.writeMessage(packet)
                            self.disconnect()

                            guard result.success else {
                                self.log.error("Pump rejected command (full hour)")
                                completion(
                                    PumpManagerError
                                        .configuration(
                                            DanaKitPumpManagerError
                                                .failedTempBasalAdjustment("Pump rejected command (full hour)")
                                        )
                                )
                                return
                            }

                            self.reportBasal(
                                unitsPerHour: unitsPerHour,
                                duration: duration,
                                percentage: percentage,
                                isTempBasal: true,
                                automatic: automatic
                            )

                            let log = "Successfully started \(durationInHours)h temp basal"
                            self.log.info(log)
                            self.logDeviceCommunication(log, type: .delegateResponse)

                            completion(nil)
                        }
                    } catch {
                        self.disconnect()

                        self.log.error("Failed to set temp basal. Error: \(error.localizedDescription)")
                        completion(PumpManagerError.communication(DanaKitPumpManagerError.unknown(error.localizedDescription)))
                    }
                default:
                    self.log.error("Connection error")
                    completion(PumpManagerError.connection(DanaKitPumpManagerError.noConnection(result)))
                    return
                }
            }
        }
    }

    private func reportBasal(unitsPerHour: Double, duration: Double, percentage _: UInt16, isTempBasal: Bool, automatic: Bool) {
        var events: [NewPumpEvent] = []
        var basalDose: UnfinalizedDose

        let startDate = Date.now
        if isTempBasal {
            basalDose = UnfinalizedDose(
                tempRate: unitsPerHour,
                duration: duration,
                insulinType: state.insulinType,
                automatic: automatic,
                startDate: startDate
            )
            events.append(NewPumpEvent.tempBasal(
                dose: basalDose.toDoseEntry(endDate: nil),
                date: startDate
            ))
        } else {
            basalDose = UnfinalizedDose(
                basalRate: state.getScheduledBasalRate(date: startDate),
                insulinType: state.insulinType,
                startDate: startDate
            )
            events.append(NewPumpEvent.basal(
                dose: basalDose.toDoseEntry(endDate: nil),
                date: startDate
            ))
        }

        if state.basalDose.type == .tempBasal {
            // Report cancelled temp basal
            events.append(NewPumpEvent.tempBasal(
                dose: state.basalDose.toDoseEntry(endDate: startDate),
                date: state.basalDose.startDate
            ))
        }

        state.basalDeliveryOrdinal = isTempBasal ? .tempBasal : .active
        state.basalDose = basalDose
        state.lastStatusDate = Date.now
        notifyStateDidChange()

        pumpDelegate.notify { delegate in
            guard let delegate = delegate else {
                self.log.error("Temp basal could not be reported -> Missing delegate")
                return
            }

            delegate.pumpManager(
                self,
                hasNewPumpEvents: events,
                lastReconciliation: self.state.lastStatusDate,
                replacePendingEvents: true,
            ) { error in
                if let error = error {
                    self.handlePumpDelegateError(method: "hasNewPumpEvents", error)
                }
            }
        }
    }

    private func isSupportedDuration(_ duration: TimeInterval) -> Bool {
        duration < .ulpOfOne || duration == .minutes(15) || duration == .minutes(30) || Int(duration) % Int(.hours(1)) == 0
    }

    public func suspendDelivery(completion: @escaping (Error?) -> Void) {
        delegateQueue.async {
            let this = self
            self.log.info("Suspend delivery")
            self.logDeviceCommunication("Suspend delivery", type: .delegate)

            self.bluetooth.ensureConnected { result in
                switch result {
                case .success:
                    do {
                        if self.state.basalDeliveryOrdinal == .tempBasal {
                            let packet = generatePacketBasalCancelTemporary()
                            let result = try self.bluetooth.writeMessage(packet)

                            guard result.success else {
                                self.disconnect()
                                self.log.error("Could not cancel old temp basal")
                                completion(
                                    PumpManagerError
                                        .configuration(
                                            DanaKitPumpManagerError
                                                .failedTempBasalAdjustment("Could not cancel old temp basal")
                                        )
                                )
                                return
                            }

                            self.log.info("Successfully canceled old temp basal")
                        }

                        let packet = generatePacketBasalSetSuspendOn()
                        let result = try self.bluetooth.writeMessage(packet)

                        let pumpTime = self.fetchPumpTime()
                        if let pumpTime = pumpTime {
                            self.state.pumpTimeSyncedAt = Date.now
                            self.state.pumpTime = pumpTime
                        }

                        self.disconnect()

                        guard result.success else {
                            self.log.error("Pump rejected command")
                            completion(PumpManagerError.configuration(DanaKitPumpManagerError.failedSuspensionAdjustment))
                            return
                        }

                        let dose = UnfinalizedDose(suspendStartTime: Date.now)
                        var events = [NewPumpEvent.suspend(dose: dose.toDoseEntry(endDate: nil))]
                        if let tempBasalEvent = self.getTempBasalEvent(endDate: dose.startDate) {
                            events.append(contentsOf: tempBasalEvent)
                        }

                        self.state.lastStatusPumpDateTime = pumpTime ?? Date.now
                        self.state.basalDeliveryOrdinal = .suspended
                        self.state.basalDose = dose
                        self.state.lastStatusDate = Date.now
                        self.notifyStateDidChange()

                        self.pumpDelegate.notify { delegate in
                            guard let delegate = delegate else {
                                this.log.error("Suspend could not be reported -> Missing delegate")
                                return
                            }

                            delegate.pumpManager(
                                this,
                                hasNewPumpEvents: events,
                                lastReconciliation: this.state.lastStatusDate,
                                replacePendingEvents: true,
                            ) { error in
                                if let error = error {
                                    this.handlePumpDelegateError(method: "hasNewPumpEvents", error)
                                }
                            }
                        }

                        self.log.info("Insulin delivery suspended!")
                        self.logDeviceCommunication("Insulin delivery suspended!", type: .delegateResponse)
                        completion(nil)
                    } catch {
                        self.disconnect()

                        self.log.error("Failed to suspend delivery. Error: \(error.localizedDescription)")
                        completion(PumpManagerError.communication(DanaKitPumpManagerError.unknown(error.localizedDescription)))
                    }
                default:
                    self.log.error("Connection error")
                    completion(PumpManagerError.connection(DanaKitPumpManagerError.noConnection(result)))
                    return
                }
            }
        }
    }

    public func resumeDelivery(completion: @escaping (Error?) -> Void) {
        delegateQueue.async {
            let this = self
            self.log.info("Resume delivery")
            self.logDeviceCommunication("Resume delivery", type: .delegate)

            self.bluetooth.ensureConnected { result in
                switch result {
                case .success:
                    do {
                        let packet = generatePacketBasalSetSuspendOff()
                        let result = try self.bluetooth.writeMessage(packet)

                        let pumpTime = self.fetchPumpTime()
                        if let pumpTime = pumpTime {
                            self.state.pumpTimeSyncedAt = Date.now
                            self.state.pumpTime = pumpTime
                        }

                        self.disconnect()

                        guard result.success else {
                            self.log.error("Pump rejected command")
                            completion(PumpManagerError.configuration(DanaKitPumpManagerError.failedSuspensionAdjustment))
                            return
                        }

                        self.state.lastStatusPumpDateTime = pumpTime ?? Date.now
                        self.state.basalDeliveryOrdinal = .active
                        self.state.basalDose = UnfinalizedDose(resumeStartTime: Date.now, insulinType: self.state.insulinType)
                        self.state.lastStatusDate = Date.now
                        self.notifyStateDidChange()

                        self.pumpDelegate.notify { delegate in
                            guard let delegate = delegate else {
                                this.log.error("Resume could not be reported -> Missing delegate")
                                return
                            }

                            delegate.pumpManager(
                                this,
                                hasNewPumpEvents: [NewPumpEvent.resume(
                                    dose: self.state.basalDose.toDoseEntry(endDate: nil)
                                )],
                                lastReconciliation: this.state.lastStatusDate,
                                replacePendingEvents: true,
                            ) { error in
                                if let error = error {
                                    this.handlePumpDelegateError(method: "hasNewPumpEvents", error)
                                }
                            }
                        }

                        self.log.info("Insulin delivery resumed!")
                        self.logDeviceCommunication("Insulin delivery resumed!", type: .delegateResponse)
                        completion(nil)
                    } catch {
                        self.disconnect()

                        self.log.error("Failed to suspend delivery. Error: \(error.localizedDescription)")
                        completion(PumpManagerError.communication(DanaKitPumpManagerError.unknown(error.localizedDescription)))
                    }
                default:
                    self.log.error("Connection error")
                    completion(PumpManagerError.connection(DanaKitPumpManagerError.noConnection(result)))
                    return
                }
            }
        }
    }

    public func syncBasalRateSchedule(
        items scheduleItems: [RepeatingScheduleValue<Double>],
        completion: @escaping (Result<BasalRateSchedule, Error>) -> Void
    ) {
        delegateQueue.async {
            self.log.info("Syncing basal schedule...")
            self.logDeviceCommunication("Syncing basal schedule...", type: .delegate)

            self.bluetooth.ensureConnected { result in
                switch result {
                case .success:
                    do {
                        let basal = DanaKitPumpManagerState.convertBasal(scheduleItems)
                        let packet =
                            try generatePacketBasalSetProfileRate(options: PacketBasalSetProfileRate(
                                profileNumber: self.state.basalProfileNumber,
                                profileBasalRate: basal
                            ))
                        let result = try self.bluetooth.writeMessage(packet)

                        guard result.success else {
                            self.disconnect()
                            self.log.error("Pump rejected command (setting rates)")
                            completion(.failure(PumpManagerError.configuration(DanaKitPumpManagerError.failedBasalAdjustment)))
                            return
                        }

                        let activatePacket =
                            generatePacketBasalSetProfileNumber(options: PacketBasalSetProfileNumber(
                                profileNumber: self.state.basalProfileNumber
                            ))
                        let activateResult = try self.bluetooth.writeMessage(activatePacket)

                        self.disconnect()

                        guard activateResult.success else {
                            self.log.error("Pump rejected command (activate profile)")
                            completion(.failure(PumpManagerError.configuration(DanaKitPumpManagerError.failedBasalAdjustment)))
                            return
                        }

                        guard let schedule = DailyValueSchedule<Double>(dailyItems: scheduleItems) else {
                            self.log.error("Failed to convert schedule")
                            completion(.failure(PumpManagerError.configuration(DanaKitPumpManagerError.failedBasalGeneration)))
                            return
                        }

                        self.state.basalSchedule = basal
                        self.notifyStateDidChange()

                        self.log.info("Basal schedule synced!")
                        self.logDeviceCommunication("Basal schedule synced!", type: .delegateResponse)
                        completion(.success(schedule))
                    } catch {
                        self.disconnect()

                        self.log.error("Failed to suspend delivery. Error: \(error.localizedDescription)")
                        completion(.failure(
                            PumpManagerError
                                .communication(DanaKitPumpManagerError.unknown(error.localizedDescription))
                        ))
                    }
                default:
                    self.log.error("Connection error")
                    completion(.failure(PumpManagerError.connection(DanaKitPumpManagerError.noConnection(result))))
                    return
                }
            }
        }
    }

    public func setUserSettings(data: PacketGeneralSetUserOption, completion: @escaping (Bool) -> Void) {
        delegateQueue.async {
            self.log.info("Syncing user settings...")
            self.logDeviceCommunication("Syncing user settings...", type: .delegate)

            self.bluetooth.ensureConnected { result in
                switch result {
                case .success:
                    do {
                        let packet = generatePacketGeneralSetUserOption(options: data)
                        let result = try self.bluetooth.writeMessage(packet)

                        self.disconnect()
                        guard result.success else {
                            self.log.error("Pump rejected command (user options)")
                            completion(false)
                            return
                        }

                        self.log.info("User settings synced!")
                        self.logDeviceCommunication("User settings synced!", type: .delegateResponse)
                        completion(true)
                    } catch {
                        self.log.error("error caught \(error.localizedDescription)")
                        self.disconnect()
                        completion(false)
                    }
                default:
                    self.log.error("Connection error")
                    completion(false)
                    return
                }
            }
        }
    }

    public func syncDeliveryLimits(limits _: DeliveryLimits, completion: @escaping (Result<DeliveryLimits, Error>) -> Void) {
        delegateQueue.async {
            // Dana does not allow the max basal and max bolus to be set
            self.log.info("Skipping sync delivery limits (not supported by dana). Fetching current settings")
            self.logDeviceCommunication(
                "Skipping sync delivery limits (not supported by dana). Fetching current settings",
                type: .delegate
            )

            self.bluetooth.ensureConnected { result in
                switch result {
                case .success:
                    do {
                        let basalPacket = generatePacketBasalGetRate()
                        let basalResult = try self.bluetooth.writeMessage(basalPacket)

                        guard basalResult.success else {
                            self.log.error("Pump refused to send basal rates back")
                            self.disconnect()
                            completion(.failure(
                                PumpManagerError
                                    .configuration(DanaKitPumpManagerError.unknown("Pump refused to send basal rates back"))
                            ))
                            return
                        }

                        let bolusPacket = generatePacketBolusGetStepInformation()
                        let bolusResult = try self.bluetooth.writeMessage(bolusPacket)

                        self.disconnect()
                        guard bolusResult.success else {
                            self.log.error("Pump refused to send bolus step back")
                            completion(.failure(
                                PumpManagerError
                                    .configuration(DanaKitPumpManagerError.unknown("Pump refused to send bolus step back"))
                            ))
                            return
                        }

                        guard let basalData = basalResult.data as? PacketBasalGetRate,
                              let bolusData = bolusResult.data as? PacketBolusGetStepInformation
                        else {
                            self.log.error("Pump sent back unexpected delivery limits")
                            completion(.failure(
                                PumpManagerError
                                    .configuration(DanaKitPumpManagerError.unknown("Pump sent back unexpected delivery limits"))
                            ))
                            return
                        }

                        self.log.info("Delivery settings received!")
                        self.logDeviceCommunication("Delivery settings received!", type: .delegateResponse)

                        completion(.success(DeliveryLimits(
                            maximumBasalRate: HKQuantity(
                                unit: HKUnit.internationalUnit().unitDivided(by: .hour()),
                                doubleValue: basalData.maxBasal
                            ),
                            maximumBolus: HKQuantity(
                                unit: .internationalUnit(),
                                doubleValue: bolusData.maxBolus
                            )
                        )))
                    } catch {
                        self.log.error("error caught \(error.localizedDescription)")
                        self.disconnect()
                        completion(.failure(
                            PumpManagerError
                                .communication(DanaKitPumpManagerError.unknown(error.localizedDescription))
                        ))
                    }
                default:
                    self.log.error("Connection error")
                    completion(.failure(PumpManagerError.connection(DanaKitPumpManagerError.noConnection(result))))
                    return
                }
            }
        }
    }

    public func syncPumpTime(completion: @escaping (Error?) -> Void) {
        delegateQueue.async {
            let this = self
            self.log.info("Syncing pump time...")
            self.logDeviceCommunication("Syncing pump time...", type: .delegate)

            self.bluetooth.ensureConnected { result in
                switch result {
                case .success:
                    do {
                        let offset = Date.now.timeIntervalSince(self.state.pumpTime ?? Date.distantPast)
                        let packet: DanaGeneratePacket
                        if self.state.usingUtc {
                            let offsetInHours = round(Double(TimeZone.current.secondsFromGMT(for: Date.now) / 3600))
                            packet =
                                generatePacketGeneralSetPumpTimeUtcWithTimezone(options: PacketGeneralSetPumpTimeUtcWithTimezone(
                                    time: Date.now,
                                    zoneOffset: UInt8(truncatingIfNeeded: Int8(offsetInHours))
                                ))
                        } else {
                            packet = generatePacketGeneralSetPumpTime(options: PacketGeneralSetPumpTime(time: Date.now))
                        }

                        let result = try self.bluetooth.writeMessage(packet)

                        let pumpTime = self.fetchPumpTime()
                        if let pumpTime = pumpTime {
                            self.state.pumpTimeSyncedAt = Date.now
                            self.state.pumpTime = pumpTime
                        }

                        self.notifyStateDidChange()

                        self.disconnect()

                        guard result.success else {
                            self.log.error("Failed to sync pump time: Pump rejected command")
                            completion(PumpManagerError.configuration(DanaKitPumpManagerError.failedTimeAdjustment))
                            return
                        }

                        self.pumpDelegate.notify { delegate in
                            guard let delegate = delegate else {
                                this.log.error("Clock offset could not be reported -> Missing delegate")
                                return
                            }

                            delegate.pumpManager(this, didAdjustPumpClockBy: offset)
                        }

                        self.log.info("Pump time synced!")
                        self.logDeviceCommunication("Pump time synced!", type: .delegateResponse)

                        completion(nil)
                    } catch {
                        self.disconnect()
                        self.log.error("Failed to sync time. Error: \(error.localizedDescription)")
                        completion(PumpManagerError.communication(DanaKitPumpManagerError.unknown(error.localizedDescription)))
                    }
                default:
                    self.log.error("Connection error")
                    completion(PumpManagerError.connection(DanaKitPumpManagerError.noConnection(result)))
                    return
                }
            }
        }
    }

    private func device() -> HKDevice {
        HKDevice(
            name: managerIdentifier,
            manufacturer: "Sooil",
            model: state.getFriendlyDeviceName(),
            hardwareVersion: String(state.hwModel),
            firmwareVersion: String(state.pumpProtocol),
            softwareVersion: "",
            localIdentifier: state.deviceName,
            udiDeviceIdentifier: nil
        )
    }

    private func absoluteBasalRateToPercentage(absoluteValue: Double, basalSchedule: [Double]) -> UInt16? {
        if absoluteValue == 0 {
            return 0
        }

        guard basalSchedule.count == 24 else {
            return nil
        }

        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let nowTimeInterval = now.timeIntervalSince(startOfDay)

        let basalIntervals: [TimeInterval] = Array(0 ..< 24).map({ TimeInterval(60 * 60 * $0) })
        let basalIndex = (basalIntervals.firstIndex(where: { $0 > nowTimeInterval }) ?? 24) - 1
        let basalRate = basalSchedule[basalIndex]

        return UInt16(round(absoluteValue / basalRate * 100))
    }
}

extension DanaKitPumpManager: AlertSoundVendor {
    public func getSoundBaseURL() -> URL? {
        nil
    }

    public func getSounds() -> [LoopKit.Alert.Sound] {
        []
    }
}

public extension DanaKitPumpManager {
    func acknowledgeAlert(alertIdentifier _: LoopKit.Alert.AlertIdentifier, completion: @escaping (Error?) -> Void) {
        completion(nil)
    }
}

// MARK: State observers

public extension DanaKitPumpManager {
    func addStatusObserver(_ observer: PumpManagerStatusObserver, queue: DispatchQueue) {
        statusObservers.insert(observer, queue: queue)
    }

    func removeStatusObserver(_ observer: PumpManagerStatusObserver) {
        statusObservers.removeElement(observer)
    }

    func addStateObserver(_ observer: StateObserver, queue: DispatchQueue) {
        stateObservers.insert(observer, queue: queue)
    }

    func removeStateObserver(_ observer: StateObserver) {
        stateObservers.removeElement(observer)
    }

    func notifyStateDidChange() {
        DispatchQueue.main.async {
            let status = self.status(self.state)
            let oldStatus = self.status(self.oldState)

            self.stateObservers.forEach { observer in
                observer.stateDidUpdate(self.state, self.oldState)
            }

            self.pumpDelegate.notify { delegate in
                guard let delegate = delegate else {
                    self.log.error("State update could not be reported -> Missing delegate")
                    return
                }

                delegate.pumpManagerDidUpdateState(self)
                delegate.pumpManager(self, didUpdate: status, oldStatus: oldStatus)
            }

            self.statusObservers.forEach { observer in
                observer.pumpManager(self, didUpdate: status, oldStatus: oldStatus)
            }

            self.oldState = DanaKitPumpManagerState(rawValue: self.state.rawValue)
        }
    }

    func addScanDeviceObserver(_ observer: StateObserver, queue: DispatchQueue) {
        scanDeviceObservers.insert(observer, queue: queue)
    }

    func removeScanDeviceObserver(_ observer: StateObserver) {
        scanDeviceObservers.removeElement(observer)
    }

    internal func notifyAlert(_ alert: PumpManagerAlert) {
        let identifier = Alert.Identifier(managerIdentifier: managerIdentifier, alertIdentifier: alert.identifier)
        let loopAlert = Alert(
            identifier: identifier,
            foregroundContent: alert.foregroundContent,
            backgroundContent: alert.backgroundContent,
            trigger: .immediate
        )

        var events = [NewPumpEvent(
            date: Date.now,
            dose: nil,
            raw: alert.raw,
            title: "Alarm: \(alert.foregroundContent.title)",
            type: .alarm,
            alarmType: alert.type
        )]
        if let tempBasalEvent = getTempBasalEvent() {
            events.append(contentsOf: tempBasalEvent)
        }

        pumpDelegate.notify { delegate in
            guard let delegate = delegate else {
                self.log.error("Alarm could not be reported -> Missing delegate")
                return
            }

            delegate.issueAlert(loopAlert)
            delegate.pumpManager(
                self,
                hasNewPumpEvents: events,
                lastReconciliation: self.state.lastStatusDate,
                replacePendingEvents: true,
            ) { error in
                if let error = error {
                    self.handlePumpDelegateError(method: "hasNewPumpEvents", error)
                }
            }
        }
    }

    internal func notifyScanDeviceDidChange(_ device: DanaPumpScan) {
        DispatchQueue.main.async {
            self.scanDeviceObservers.forEach { observer in
                observer.deviceScanDidUpdate(device)
            }
        }
    }

    internal func notifyBolusError() {
        guard let doseEntry = state.bolusDose, state.bolusState != .noBolus else {
            // Ignore if no bolus is going
            return
        }

        logDeviceCommunication("Error during bolus - \(doseEntry.deliveredUnits)U of \(doseEntry.value)U", type: .error)

        doseReporter = nil
        state.bolusDose = nil
        state.bolusState = .noBolus
        state.lastStatusDate = Date.now
        notifyStateDidChange()
    }

    internal func notifyBolusDidUpdate(deliveredUnits: Double) {
        guard let doseEntry = state.bolusDose else {
            log.error("No bolus entry found...")
            return
        }

        doseEntry.deliveredUnits = deliveredUnits
        doseReporter?.notify(deliveredUnits: deliveredUnits)
        notifyStateDidChange()

        let currentStep = Int(deliveredUnits)
        if currentStep > lastReportedBolusStep {
            lastReportedBolusStep = currentStep
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let command = generatePacketGeneralKeepConnection()
                    let result = try self.bluetooth.writeMessage(command)

                    guard result.success else {
                        self.log.warning("Pump declined keepalive")
                        return
                    }

                    self.log.info("Pump accepted keepalive")
                } catch {
                    self.log.error("Failed to send keepalive: \(error)")
                }
            }
        }
    }

    internal func notifyBolusDone(deliveredUnits: Double) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else {
                return
            }

            self.log.info("Bolus completed - \(deliveredUnits)U")
            self.logDeviceCommunication("Bolus completed - \(deliveredUnits)U", type: .delegateResponse)

            let bolusCompletedAt = Date.now

            do {
                let resultInitialScreenInformation = try self.bluetooth
                    .writeMessage(generatePacketGeneralGetInitialScreenInformation())
                if resultInitialScreenInformation.success,
                   let data = resultInitialScreenInformation.data as? PacketGeneralGetInitialScreenInformation
                {
                    state.reservoirLevel = data.reservoirRemainingUnits
                }
            } catch {}

            self.state.lastStatusPumpDateTime = fetchPumpTime() ?? Date.now
            self.state.lastStatusDate = Date.now
            self.state.bolusState = .noBolus
            self.notifyStateDidChange()

            let work = DispatchWorkItem { [weak self] in
                self?.disconnect()
            }

            self.delegateQueue.asyncAfter(deadline: .now() + 1, execute: work)

            guard let doseEntry = state.bolusDose else {
                log.error("No doseEntry available...")
                return
            }

            doseEntry.deliveredUnits = deliveredUnits
            let dose = doseEntry.toDoseEntry(endDate: bolusCompletedAt)

            self.doseReporter = nil
            self.state.bolusDose = nil

            guard !self.isPriming else {
                log.debug("PumpManager is in priming mode -> Skip reporting dose")
                return
            }

            var events = [NewPumpEvent.bolus(dose: dose, date: dose.startDate)]
            if let tempBasalEvent = getTempBasalEvent() {
                events.append(contentsOf: tempBasalEvent)
            }

            self.pumpDelegate.notify { delegate in
                guard let delegate = delegate else {
                    self.log.error("Dose could not be reported -> Missing delegate")
                    return
                }

                delegate.pumpManager(
                    self,
                    didReadReservoirValue: self.state.reservoirLevel,
                    at: self.state.lastStatusDate,
                ) { result in
                    switch result {
                    case let .failure(error):
                        self.handlePumpDelegateError(method: "didReadReservoirValue", error)
                    case .success:
                        break
                    }
                }
                delegate.pumpManager(
                    self,
                    hasNewPumpEvents: events,
                    lastReconciliation: self.state.lastStatusDate,
                    replacePendingEvents: true,
                ) { error in
                    if let error = error {
                        self.handlePumpDelegateError(method: "hasNewPumpEvents", error)
                    }
                }
            }
        }
    }

    internal func checkBolusDone() {
        guard let doseEntry = state.bolusDose else {
            // Disconnect was done after bolus was complete!
            return
        }

        // There was a bolus going on, unsure if the bolus is completed...
        log.warning("Disconnected from pump while ongoing bolus - \(doseEntry.deliveredUnits)U of \(doseEntry.value)U")
        logDeviceCommunication(
            "Disconnected from pump while ongoing bolus - \(doseEntry.deliveredUnits)U of \(doseEntry.value)U",
            type: .error
        )

        // We assume the bolus will be completed
        doseEntry.deliveredUnits = doseEntry.value
        let dose = doseEntry.toDoseEntry(endDate: Date.now)

        var events = [NewPumpEvent.bolus(dose: dose, date: dose.startDate)]
        if let tempBasal = getTempBasalEvent() {
            events.append(contentsOf: tempBasal)
        }

        state.bolusState = .noBolus
        state.bolusDose = nil
        state.lastStatusDate = Date.now
        notifyStateDidChange()

        pumpDelegate.notify { delegate in
            guard let delegate = delegate else {
                self.log.error("Uncertain delivery could not be reported -> Missing delegate")
                return
            }

            delegate.pumpManager(self, didError: .uncertainDelivery)
            delegate.pumpManager(
                self,
                hasNewPumpEvents: events,
                lastReconciliation: self.state.lastStatusDate,
                replacePendingEvents: true,
            ) { error in
                if let error = error {
                    self.handlePumpDelegateError(method: "hasNewPumpEvents", error)
                }
            }
        }
    }

    internal func logDeviceCommunication(_ message: String, type: DeviceLogEntryType = .send) {
        let address = String(format: "%04X", state.bleIdentifier ?? "")
        // Not dispatching here; if delegate queue is blocked, timestamps will be delayed
        pumpManagerDelegate?.deviceManager(
            self,
            logEventForDeviceIdentifier: address,
            type: type,
            message: message,
            completion: nil
        )
    }

    func handlePumpDelegateError(method: String, _ error: Error, _ function: String = #function, _ line: Int = #line) {
        let logLine = "Received pump delegate error in \(method): \(error) at \(function):\(line)"
        log.error(logLine)
        logDeviceCommunication(logLine, type: .error)
    }
}
