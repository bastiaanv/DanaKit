import HealthKit
import LoopKit
import SwiftUI

class DanaKitSettingsViewModel: ObservableObject {
    @Published var showingDeleteConfirmation = false
    @Published var showingBleModeSwitch = false
    @Published var showingTimeSyncConfirmation = false
    @Published var showingDisconnectReminder = false
    @Published var showingBolusSyncingDisabled = false
    @Published var showingBlindReservoirCannulaRefill = false
    @Published var bolusSpeed: BolusSpeed = .speed12
    @Published var isUsingContinuousMode: Bool = false
    @Published var isUpdatingPumpState: Bool = false
    @Published var isConnected: Bool = false
    @Published var isTogglingConnection: Bool = false
    @Published var isBolusSyncingDisabled = false
    @Published var isSyncing: Bool = false
    @Published var lastSync: Date?
    @Published var batteryLevel: Double = 0
    @Published var showingSilentTone: Bool = false
    @Published var silentTone: Bool = false
    @Published var basalProfileNumber: UInt8 = 0
    @Published var cannulaAge: String?
    @Published var reservoirAge: String?
    @Published var batteryAge: String?
    @Published var deviceName: String?
    @Published var hardwareModel: UInt8?
    @Published var firmwareVersion: UInt8?

    @Published var showPumpTimeSyncWarning: Bool = false
    @Published var pumpTime: Date?
    @Published var pumpTimeSyncedAt: Date?
    @Published var nightlyPumpTimeSync: Bool = false

    @Published var reservoirLevelWarning: Double = 20
    @Published var reservoirLevel: Double?
    @Published var isSuspended: Bool = false
    @Published var basalRate: Double?

    private let log = DanaLogger(category: "SettingsView")
    private(set) var insulinType: InsulinType = .novolog
    private(set) var pumpManager: DanaKitPumpManager?
    private var didFinish: (() -> Void)?

    let toUserOptions: () -> Void
    let toBolusSpeed: () -> Void
    let toInsulinType: () -> Void
    let toRefill: (Bool) -> Void

    public var isTempBasal: Bool {
        guard let pumpManager = self.pumpManager else {
            return false
        }

        return pumpManager.state.basalDeliveryOrdinal == .tempBasal
    }

    public var isTempBasalManual: Bool {
        isTempBasal && !(pumpManager?.state.basalDose.automatic ?? true)
    }

    public var isSuspendActionLocked: Bool {
        guard let pumpManager else {
            return true
        }

        return pumpManager.state.basalDose.type != .suspend
    }

    public var isTempBasalLocked: Bool {
        guard let pumpManager = self.pumpManager else {
            return false
        }

        return !(pumpManager.state.basalDeliveryOrdinal == .tempBasal && pumpManager.state.basalDose.expectedEndDate > Date.now)
    }

    var tempBasalRemaining: String? {
        guard isTempBasal, let pumpManager else {
            return nil
        }

        let remaining = pumpManager.state.basalDose.expectedEndDate.timeIntervalSinceNow
        let hours = Int(floor(remaining.hours))
        let minutes = Int(floor(remaining.minutes))

        if hours > 0 {
            return String(
                format: String(localized: "%lld hr %lld min", comment: "temp basal remaining hours+minutes"),
                hours,
                minutes - hours * 60
            )
        }

        return String(
            format: String(localized: "%lld min", comment: "temp basal remaining minutes"),
            minutes
        )
    }

    private let dateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter
    }()

    private let countdownFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 2
        return formatter
    }()

    func formatRemaining(until endDate: Date, now: Date = Date.now) -> String {
        let remaining = max(0, endDate.timeIntervalSince(now))
        return countdownFormatter.string(from: remaining) ?? ""
    }

    public init(
        _ pumpManager: DanaKitPumpManager?,
        toUserOptions: @escaping () -> Void,
        toBolusSpeed: @escaping () -> Void,
        toInsulinType: @escaping () -> Void,
        toRefill: @escaping (Bool) -> Void,
        didFinish: (() -> Void)?
    ) {
        self.pumpManager = pumpManager
        self.toUserOptions = toUserOptions
        self.toBolusSpeed = toBolusSpeed
        self.toInsulinType = toInsulinType
        self.toRefill = toRefill
        self.didFinish = didFinish

        if let pumpManager {
            stateDidUpdate(pumpManager.state, pumpManager.state)
            pumpManager.addStateObserver(self, queue: .main)
        }
    }

    func stopUsingDana() {
        pumpManager?.notifyDelegateOfDeactivation {
            DispatchQueue.main.async {
                self.didFinish?()
            }
        }
    }

    func updateReservoirAge() {
        pumpManager?.state.reservoirDate = Date.now
        reservoirAge = formatDateToDayHour(Date.now)
        pumpManager?.notifyStateDidChange()
    }

    func updateCannulaAge() {
        pumpManager?.state.cannulaDate = Date.now
        cannulaAge = formatDateToDayHour(Date.now)
        pumpManager?.notifyStateDidChange()
    }

    func updateBatteryAge() {
        pumpManager?.state.batteryAge = Date.now
        batteryAge = formatDateToDayHour(Date.now)
        pumpManager?.notifyStateDidChange()
    }

    func scheduleDisconnectNotification(_ duration: TimeInterval) {
        NotificationHelper.setDisconnectReminder(duration)
        pumpManager?.disconnect(true)
    }

    func forceDisconnect() {
        pumpManager?.disconnect(true)
    }

    func getScheduledBasal() -> Double {
        pumpManager?.state.getScheduledBasalRate() ?? 0
    }

    func didChangeInsulinType(_ newType: InsulinType?) {
        guard let type = newType else {
            return
        }

        pumpManager?.state.insulinType = type
        pumpManager?.notifyStateDidChange()
        insulinType = type
    }

    func getLogs() -> [URL] {
        if let pumpManager = self.pumpManager {
            log.info(pumpManager.state.debugDescription)
        }
        return log.getDebugLogs()
    }

    func toggleBleMode() {
        pumpManager?.toggleBluetoothMode()
        isTogglingConnection = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            self.isTogglingConnection = false
        }
    }

    func reconnect() {
        guard let pumpManager = self.pumpManager else {
            return
        }

        isTogglingConnection = true
        pumpManager.reconnect { _ in
            DispatchQueue.main.async {
                self.isTogglingConnection = false
            }
        }
    }

    func formatDate(_ date: Date?) -> String {
        guard let date = date else {
            return ""
        }

        return dateFormatter.string(from: date)
    }

    func didBolusSpeedChanged(_ bolusSpeed: BolusSpeed) {
        pumpManager?.state.bolusSpeed = bolusSpeed
        pumpManager?.notifyStateDidChange()
        self.bolusSpeed = bolusSpeed
    }

    func syncData() {
        guard let pumpManager = self.pumpManager else {
            return
        }

        DispatchQueue.main.async {
            self.isSyncing = true
        }

        pumpManager.syncPump { date in
            DispatchQueue.main.async {
                self.isSyncing = false

                if let date = date {
                    self.lastSync = date
                }
            }
        }
    }

    func updateNightlyPumpTimeSync(_ value: Bool) {
        guard let pumpManager = self.pumpManager else {
            return
        }

        pumpManager.state.allowAutomaticTimeSync = value
        pumpManager.notifyStateDidChange()
    }

    func syncPumpTime() {
        guard let pumpManager = self.pumpManager else {
            return
        }

        isSyncing = true
        pumpManager.syncPumpTime { _ in
            DispatchQueue.main.async {
                self.isSyncing = false
            }
        }
    }

    func toggleSilentTone() {
        guard let pumpManager = self.pumpManager else {
            return
        }

        pumpManager.state.useSilentTones = !silentTone
        silentTone = pumpManager.state.useSilentTones
    }

    func toggleBolusSyncing() {
        guard let pumpManager = self.pumpManager else {
            return
        }

        pumpManager.state.isBolusSyncDisabled = !isBolusSyncingDisabled
        pumpManager.notifyStateDidChange()
    }

    func transformBasalProfile(_ index: UInt8) -> String {
        if index == 0 {
            return "A"
        } else if index == 1 {
            return "B"
        } else if index == 2 {
            return "C"
        } else {
            return "D"
        }
    }

    func stopTempBasal() {
        guard let pumpManager = self.pumpManager else {
            return
        }

        if isTempBasalLocked || isUpdatingPumpState || isSyncing {
            return
        }

        isUpdatingPumpState = true

        // Stop temp basal
        pumpManager.enactTempBasal(unitsPerHour: 0, for: 0, completion: { error in
            DispatchQueue.main.async {
                self.isUpdatingPumpState = false
            }

            // Check if action failed, otherwise skip state sync
            guard error == nil else {
                self.log.error("\(#function): failed to stop temp basal. Error: \(error!.localizedDescription)")
                return
            }
        })
    }

    func suspendResumeButtonPressed() {
        guard let pumpManager = self.pumpManager else {
            return
        }

        if isSuspendActionLocked || isUpdatingPumpState || isSyncing {
            return
        }

        isUpdatingPumpState = true

        if pumpManager.state.basalDeliveryOrdinal == .suspended {
            self.pumpManager?.resumeDelivery { error in
                DispatchQueue.main.async {
                    self.isUpdatingPumpState = false
                }

                // Check if action failed, otherwise skip state sync
                guard error == nil else {
                    self.log.error("\(#function): failed to resume delivery. Error: \(error!.localizedDescription)")
                    return
                }
            }

            return
        }

        pumpManager.suspendDelivery(completion: { error in
            DispatchQueue.main.async {
                self.isUpdatingPumpState = false
            }

            // Check if action failed, otherwise skip state sync
            guard error == nil else {
                self.log.error("\(#function): failed to suspend delivery. Error: \(error!.localizedDescription)")
                return
            }
        })
    }

    func enactManualTempBasal(_ rate: UInt16, for duration: TimeInterval, completion: @escaping (PumpManagerError?) -> Void) {
        guard let pumpManager = self.pumpManager else {
            return
        }

        return pumpManager.enactTempBasal(percentage: rate, for: duration, automatic: false, completion: completion)
    }

    private func updateBasalRate() {
        guard let pumpManager = self.pumpManager else {
            basalRate = 0
            return
        }

        if pumpManager.state.basalDeliveryOrdinal == .tempBasal {
            basalRate = pumpManager.state.basalDose.value
        } else {
            basalRate = pumpManager.state.getScheduledBasalRate()
        }
    }

    private func formatDateToDayHour(_ date: Date) -> String {
        let components = Calendar.current.dateComponents([.day, .hour, .minute, .second], from: date, to: Date.now)
        if let days = components.day, let hours = components.hour {
            return "\(days)d \(hours)h"
        }

        return "?d ?h"
    }
}

extension DanaKitSettingsViewModel: StateObserver {
    func stateDidUpdate(_ state: DanaKitPumpManagerState, _: DanaKitPumpManagerState) {
        isUsingContinuousMode = state.isUsingContinuousMode
        isConnected = state.isConnected
        insulinType = state.insulinType ?? .novolog
        bolusSpeed = state.bolusSpeed
        lastSync = state.lastStatusDate
        reservoirLevel = state.reservoirLevel
        isSuspended = state.basalDeliveryOrdinal == .suspended
        isBolusSyncingDisabled = state.isBolusSyncDisabled
        pumpTime = state.pumpTime
        pumpTimeSyncedAt = state.pumpTimeSyncedAt
        nightlyPumpTimeSync = state.allowAutomaticTimeSync
        batteryLevel = state.batteryRemaining
        silentTone = state.useSilentTones
        basalProfileNumber = state.basalProfileNumber
        showPumpTimeSyncWarning = state.shouldShowTimeWarning()
        deviceName = pumpManager?.state.deviceName
        hardwareModel = pumpManager?.state.hwModel
        firmwareVersion = pumpManager?.state.pumpProtocol
        updateBasalRate()

        if let cannulaDate = state.cannulaDate {
            cannulaAge = formatDateToDayHour(cannulaDate)
        }

        if let reservoirDate = state.reservoirDate {
            reservoirAge = formatDateToDayHour(reservoirDate)
        }

        if let batteryAge = state.batteryAge {
            self.batteryAge = formatDateToDayHour(batteryAge)
        }
    }

    func deviceScanDidUpdate(_: DanaPumpScan) {
        // Don't do anything here. We are not scanning for a new pump
    }
}
