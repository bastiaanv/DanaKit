//
//  DanaKitPumpManager.swift
//  DanaKit
//
//  Based on OmniKit/PumpManager/OmnipodPumpManager.swift
//  Created by Pete Schwamb on 8/4/18.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

import HealthKit
import LoopKit
import UserNotifications
import os.log
import CoreBluetooth


public class DanaKitPumpManager: DeviceManager {
    public var rawState: PumpManager.RawStateValue {
        return state
    }

    public static let pluginIdentifier: String = "Dana" // use a single token to make parsing log files easier
    public let managerIdentifier: String = "Dana"

    public let localizedTitle = LocalizedString("Dana", comment: "Generic title of the DanaKit pump manager")

    public init(state: DanaKitPumpManagerState, dateGenerator: @escaping () -> Date = Date.init) {
        self.lockedState = Locked(state)
        self.state = state.rawValue
    }

    public required convenience init?(rawState: PumpManager.RawStateValue) {
        guard let state = DanaKitPumpManagerState(rawValue: rawState) else
        {
            return nil
        }

        self.init(state: state)
    }

    private let state: PumpManager.RawStateValue
    private let lockedState: Locked<DanaKitPumpManagerState>

    public var isOnboarded: Bool {
        false
    }
    
    public var debugDescription: String {
        let lines = [
            "## DanaKitPumpManager",
            "TODO"
        ]
        return lines.joined(separator: "\n")
    }
}

// TODO: Implement
extension DanaKitPumpManager: PumpManager {
    public static var onboardingMaximumBasalScheduleEntryCount: Int {
        return 0
    }
    
    public static var onboardingSupportedBasalRates: [Double] {
        return []
    }
    
    public static var onboardingSupportedBolusVolumes: [Double] {
        return []
    }
    
    public static var onboardingSupportedMaximumBolusVolumes: [Double] {
        return []
    }
    
    public var delegateQueue: DispatchQueue! {
        get {
            return nil
        }
        set(newValue) {
        }
    }
    
    public var supportedBasalRates: [Double] {
        return []
    }
    
    public var supportedBolusVolumes: [Double] {
        return []
    }
    
    public var supportedMaximumBolusVolumes: [Double] {
        return []
    }
    
    public var maximumBasalScheduleEntryCount: Int {
        return 0
    }
    
    public var minimumBasalScheduleEntryDuration: TimeInterval {
        return 0
    }
    
    public var pumpManagerDelegate: LoopKit.PumpManagerDelegate? {
        get {
            return nil
        }
        set(newValue) {
        }
    }
    
    public var pumpRecordsBasalProfileStartEvents: Bool {
        return false
    }
    
    public var pumpReservoirCapacity: Double {
        return 0
    }
    
    public var lastSync: Date? {
        return nil
    }
    
    public var status: LoopKit.PumpManagerStatus {
        return PumpManagerStatus(timeZone: TimeZone(identifier: "Europe/Amsterdam")!, device: device(), pumpBatteryChargeRemaining: nil, basalDeliveryState: nil, bolusState: .noBolus, insulinType: nil)
    }
    
    public func addStatusObserver(_ observer: LoopKit.PumpManagerStatusObserver, queue: DispatchQueue) {
    }
    
    public func removeStatusObserver(_ observer: LoopKit.PumpManagerStatusObserver) {
    }
    
    public func ensureCurrentPumpData(completion: ((Date?) -> Void)?) {
    }
    
    public func setMustProvideBLEHeartbeat(_ mustProvideBLEHeartbeat: Bool) {
    }
    
    public func createBolusProgressReporter(reportingOn dispatchQueue: DispatchQueue) -> LoopKit.DoseProgressReporter? {
        return nil
    }
    
    public func estimatedDuration(toBolus units: Double) -> TimeInterval {
        return 0
    }
    
    public func enactBolus(units: Double, activationType: LoopKit.BolusActivationType, completion: @escaping (LoopKit.PumpManagerError?) -> Void) {
    }
    
    public func cancelBolus(completion: @escaping (LoopKit.PumpManagerResult<LoopKit.DoseEntry?>) -> Void) {
    }
    
    public func enactTempBasal(unitsPerHour: Double, for duration: TimeInterval, completion: @escaping (LoopKit.PumpManagerError?) -> Void) {
    }
    
    public func suspendDelivery(completion: @escaping (Error?) -> Void) {
    }
    
    public func resumeDelivery(completion: @escaping (Error?) -> Void) {
    }
    
    public func syncBasalRateSchedule(items scheduleItems: [LoopKit.RepeatingScheduleValue<Double>], completion: @escaping (Result<LoopKit.BasalRateSchedule, Error>) -> Void) {
    }
    
    public func syncDeliveryLimits(limits deliveryLimits: LoopKit.DeliveryLimits, completion: @escaping (Result<LoopKit.DeliveryLimits, Error>) -> Void) {
    }
    
    private func device() -> HKDevice {
        return HKDevice(
            name: managerIdentifier,
            manufacturer: "Sooil",
            model: "Dana",
            hardwareVersion: nil,
            firmwareVersion: nil,
            softwareVersion: "",
            localIdentifier: nil,
            udiDeviceIdentifier: nil
        )
    }
}

extension DanaKitPumpManager: AlertSoundVendor {
    public func getSoundBaseURL() -> URL? {
        return nil
    }

    public func getSounds() -> [Alert.Sound] {
        return []
    }
}

extension DanaKitPumpManager {
    public func acknowledgeAlert(alertIdentifier: Alert.AlertIdentifier, completion: @escaping (Error?) -> Void) {
    }
}
