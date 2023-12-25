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

public protocol StateObserver: AnyObject {
    func stateDidUpdate(_ state: DanaKitPumpManagerState)
    func deviceScanDidUpdate(_ devices: [DanaPumpScan])
}

public class DanaKitPumpManager: DeviceManager {
    private var bluetoothManager: BluetoothManager!
    
    public var state: DanaKitPumpManagerState
    public var rawState: PumpManager.RawStateValue {
        return state.rawValue
    }

    public static let pluginIdentifier: String = "Dana" // use a single token to make parsing log files easier
    public let managerIdentifier: String = "Dana"

    public let localizedTitle = LocalizedString("Dana-i/RS", comment: "Generic title of the DanaKit pump manager")

    public init(state: DanaKitPumpManagerState, dateGenerator: @escaping () -> Date = Date.init) {
        self.state = state
        
        self.bluetoothManager = BluetoothManager(self)
    }

    public required convenience init?(rawState: PumpManager.RawStateValue) {
        self.init(state: DanaKitPumpManagerState(rawValue: rawState))
    }

    private let log = OSLog(category: "DanaKitPumpManager")
    
    private let stateObservers = WeakSynchronizedSet<StateObserver>()
    private let scanDeviceObservers = WeakSynchronizedSet<StateObserver>()

    public var isOnboarded: Bool {
        self.state.deviceName != nil
    }
    
    public var currentBaseBasalRate: Double = 0
    
    public var debugDescription: String {
        let lines = [
            "## DanaKitPumpManager",
            "TODO"
        ]
        return lines.joined(separator: "\n")
    }
    
    public func connect(_ bleIdentifier: String) {
        do {
            try self.bluetoothManager.connect(bleIdentifier)
        } catch {
            log.error("Failed to connect: %{public}@", String(describing: error))
        }
    }
    
    public func connect(_ peripheral: CBPeripheral) {
        self.bluetoothManager.connect(peripheral)
    }
    
    public func disconnect(_ peripheral: CBPeripheral) {
        self.bluetoothManager.disconnect(peripheral)
    }
    
    public func startScan() {
        self.bluetoothManager.startScan()
    }
    
    public func stopScan() {
        self.bluetoothManager.stopScan()
    }
    
    public func setBasal(_ basal: [Double]) {
        Task {
            do {
                let packet = try generatePacketBasalSetProfileRate(options: PacketBasalSetProfileRate(profileNumber: UInt8(1), profileBasalRate: basal))
                let result = try await self.bluetoothManager.writeMessage(packet)
            }

        }
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
        return Double(self.state.reservoirLevel)
    }
    
    public var lastSync: Date? {
        return self.state.lastStatusDate
    }
    
    public var status: LoopKit.PumpManagerStatus {
        return PumpManagerStatus(timeZone: TimeZone(identifier: "Europe/Amsterdam")!, device: device(), pumpBatteryChargeRemaining: nil, basalDeliveryState: nil, bolusState: .noBolus, insulinType: nil)
    }
    
    public func addStatusObserver(_ observer: PumpManagerStatusObserver, queue: DispatchQueue) {
    }
    
    public func removeStatusObserver(_ observer: PumpManagerStatusObserver) {
    }
    
    public func ensureCurrentPumpData(completion: ((Date?) -> Void)?) {
    }
    
    public func setMustProvideBLEHeartbeat(_ mustProvideBLEHeartbeat: Bool) {
    }
    
    public func createBolusProgressReporter(reportingOn dispatchQueue: DispatchQueue) -> LoopKit.DoseProgressReporter? {
        return nil
    }
    
    public func estimatedDuration(toBolus units: Double) -> TimeInterval {
        switch(self.state.bolusSpeed) {
        case .speed12:
            return units / 720
        case .speed30:
            return units / 1800
        case .speed60:
            return units / 3600
        }
    }
    
    public func enactBolus(units: Double, activationType: BolusActivationType, completion: @escaping (PumpManagerError?) -> Void) {
        Task {
            do {
                let packet = generatePacketBolusStart(options: PacketBolusStart(amount: units, speed: self.state.bolusSpeed))
                let result = try await self.bluetoothManager.writeMessage(packet)
                
                if (!result.success) {
                    completion(PumpManagerError.uncertainDelivery)
                    return
                }
                
                completion(nil)
            } catch {
                completion(PumpManagerError.uncertainDelivery)
            }
        }
    }
    
    public func cancelBolus(completion: @escaping (PumpManagerResult<DoseEntry?>) -> Void) {
        Task {
            do {
                let packet = generatePacketBolusStop()
                let result = try await self.bluetoothManager.writeMessage(packet)
                
                if (!result.success) {
                    completion(.failure(PumpManagerError.communication(nil)))
                    return
                }
                
                completion(.success(nil))
            } catch {
                log.error("%{public}@: Failed to cancel bolus", #function)
                completion(.failure(PumpManagerError.communication(nil)))
            }
        }
    }
    
    /// NOTE: There are 2 ways to set a temp basal:
    /// - The normal way (which only accepts full hours)
    /// - A short APS-special temp basal command (which only accepts 15 (only above 100%) or 30 min (only below 100%)
    /// TODO: Need to discuss what to do here / how to make this work within the Loop algorithm AND if the convertion from absolute to percentage is acceptable
    public func enactTempBasal(unitsPerHour: Double, for duration: TimeInterval, completion: @escaping (PumpManagerError?) -> Void) {
        Task {
            if (duration < .ulpOfOne) {
                do {
                    let packet = generatePacketBasalCancelTemporary()
                    let result = try await self.bluetoothManager.writeMessage(packet)
                    
                    if (!result.success) {
                        completion(PumpManagerError.communication(nil))
                        return
                    }
                    
                    completion(nil)
                } catch {
                    log.error("%{public}@: Failed to cancel temp basal", #function)
                    completion(PumpManagerError.communication(nil))
                }
            } else {
                do {
                    var tempBasalPercentage: UInt8 = 0
                    // Any basal less than 0.10u/h will be dumped once per hour. So if it's less than .10u/h, set a zero temp.
                    if (unitsPerHour >= 0.1) {
                        tempBasalPercentage = UInt8(ceil(unitsPerHour / currentBaseBasalRate * 100))
                    }
                    
                    let durationInHours = UInt8(round(duration / 3600))
                    let packet = generatePacketBasalSetTemporary(options: PacketBasalSetTemporary(temporaryBasalRatio: tempBasalPercentage, temporaryBasalDuration: durationInHours))
                    let result = try await self.bluetoothManager.writeMessage(packet)
                    
                    if (!result.success) {
                        completion(PumpManagerError.communication(nil))
                        return
                    }
                    
                    completion(nil)
                } catch {
                    log.error("%{public}@: Failed to set temp basal", #function)
                    completion(PumpManagerError.communication(nil))
                }
            }
        }
    }
    
    public func suspendDelivery(completion: @escaping (Error?) -> Void) {
        Task {
            do {
                let packet = generatePacketBasalSetSuspendOn()
                let result = try await self.bluetoothManager.writeMessage(packet)
                
                if (!result.success) {
                    completion(PumpManagerError.communication(nil))
                    return
                }
                
                completion(nil)
            } catch {
                log.error("%{public}@: Failed to suspend pump", #function)
                completion(PumpManagerError.communication(nil))
            }
        }
    }
    
    public func resumeDelivery(completion: @escaping (Error?) -> Void) {
        Task {
            do {
                let packet = generatePacketBasalSetSuspendOff()
                let result = try await self.bluetoothManager.writeMessage(packet)
                
                if (!result.success) {
                    completion(PumpManagerError.communication(nil))
                    return
                }
                
                completion(nil)
            } catch {
                log.error("%{public}@: Failed to resume pump", #function)
                completion(PumpManagerError.communication(nil))
            }
        }
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

extension DanaKitPumpManager {
    // MARK: State observers
    public func addStateObserver(_ observer: StateObserver, queue: DispatchQueue) {
        stateObservers.insert(observer, queue: queue)
    }

    public func removeStateObserver(_ observer: StateObserver) {
        stateObservers.removeElement(observer)
    }
    
    func notifyStateDidChange() {
        stateObservers.forEach { (observer) in
            observer.stateDidUpdate(self.state)
        }
    }
    
    public func addScanDeviceObserver(_ observer: StateObserver, queue: DispatchQueue) {
        scanDeviceObservers.insert(observer, queue: queue)
    }

    public func removeScanDeviceObserver(_ observer: StateObserver) {
        scanDeviceObservers.removeElement(observer)
    }
    
    func notifyScanDeviceDidChange(_ devices: [DanaPumpScan]) {
        scanDeviceObservers.forEach { (observer) in
            observer.deviceScanDidUpdate(devices)
        }
    }
}
