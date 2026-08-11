import Foundation
import LoopKit

// MARK: - History / pump data sync

extension DanaKitPumpManager {
    public func syncPump(_ completion: ((Date?) -> Void)?) {
        delegateQueue.async {
            let this = self
            self.log.info("Syncing pump data")
            self.logDeviceCommunication("Syncing pump data", type: .delegate)

            self.bluetooth.ensureConnected { result in
                switch result {
                case .success:
                    self.syncUserOptions()
                    var events = self.syncHistory()

                    // Re-report any in-progress (or just-expired) temp basal and any pending bolus on
                    // every sync. Mutable doses only persist in Loop for as long as they are reported,
                    // and are otherwise purged (PumpManagerDoseReporting.md §3).
                    if let tempBasalEvent = self.getTempBasalEvent() {
                        events.append(tempBasalEvent)
                    }
                    if let pendingBolusEvent = self.getPendingBolusEvent() {
                        events.append(pendingBolusEvent)
                    }

                    if self.shouldSyncTime() {
                        self.syncTime()
                    }

                    let pumpTime = self.fetchPumpTime()
                    if let pumpTime = pumpTime {
                        self.state.pumpTimeSyncedAt = Date.now
                        self.state.pumpTime = pumpTime
                    }

                    self.state.lastStatusPumpDateTime = pumpTime ?? Date.now
                    self.state.lastStatusDate = Date.now
                    self.disconnect()

                    self.issueHeartbeatIfNeeded()
                    self.notifyStateDidChange()

                    self.pumpDelegate.notify { delegate in
                        guard let delegate = delegate else {
                            this.log.error("Reservoir level & last check could not be reported -> Missing delegate")
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
                        delegate.pumpManager(
                            this,
                            didReadReservoirValue: this.state.reservoirLevel,
                            at: this.state.lastStatusDate,
                        ) { result in
                            switch result {
                            case let .failure(error):
                                this.handlePumpDelegateError(method: "didReadReservoirValue", error)
                            case .success:
                                break
                            }
                        }
                        delegate.pumpManagerDidUpdateState(this)
                    }

                    self.log.info("Sync successful!")
                    completion?(Date.now)
                default:
                    completion?(nil)
                    return
                }
            }
        }
    }

    private func syncTime() {
        syncPumpTime { error in
            if let error = error {
                self.log.error("Failed to automaticly sync pump time: \(error.localizedDescription)")
            }
        }
    }

    private func shouldSyncTime() -> Bool {
        guard state.allowAutomaticTimeSync else {
            return false
        }
        guard let pumpTime = state.pumpTime else {
            return false
        }

        let pumpTimeComp = Calendar.current.dateComponents([.day], from: pumpTime)
        let nowComp = Calendar.current.dateComponents([.day], from: Date.now)
        return pumpTimeComp.day != nowComp.day
    }

    private func syncUserOptions() {
        do {
            let userOptionPacket = generatePacketGeneralGetUserOption()
            let userOptionResult = try bluetooth.writeMessage(userOptionPacket)
            guard userOptionResult.success else {
                log.error("Failed to fetch user options...")
                return
            }

            guard let dataUserOption = userOptionResult.data as? PacketGeneralGetUserOption else {
                log.error("Received unexpected data while fetching user options...")
                return
            }

            state.lowReservoirRate = dataUserOption.lowReservoirRate
            state.isTimeDisplay24H = dataUserOption.isTimeDisplay24H
            state.isButtonScrollOnOff = dataUserOption.isButtonScrollOnOff
            state.beepAndAlarm = dataUserOption.beepAndAlarm
            state.lcdOnTimeInSec = dataUserOption.lcdOnTimeInSec
            state.backlightOnTimInSec = dataUserOption.backlightOnTimInSec
            state.selectedLanguage = dataUserOption.selectedLanguage
            state.units = dataUserOption.units
            state.shutdownHour = dataUserOption.shutdownHour
            state.cannulaVolume = dataUserOption.cannulaVolume
            state.refillAmount = dataUserOption.refillAmount
            state.targetBg = dataUserOption.targetBg
            state.units = dataUserOption.units
        } catch {
            log.error("Failed to sync user options: \(error.localizedDescription)")
        }
    }

    func fetchPumpTime() -> Date? {
        do {
            let timePacket = state
                .usingUtc ? generatePacketGeneralGetPumpTimeUtcWithTimezone() : generatePacketGeneralGetPumpTime()
            let timeResult = try bluetooth.writeMessage(timePacket)

            guard timeResult.success else {
                log.error("Failed to fetch pump time with utc...")
                return nil
            }

            if let data = timeResult.data as? PacketGeneralGetPumpTimeUtcWithTimezone {
                state.pumpTimeZone = TimeZone(secondsFromGMT: data.timezoneOffset * 3600)
            }

            let date = state.usingUtc ? (timeResult.data as? PacketGeneralGetPumpTimeUtcWithTimezone)?
                .time : (timeResult.data as? PacketGeneralGetPumpTime)?.time
            guard let date = date else {
                return nil
            }

            return date
        } catch {
            log.error("Failed to sync time: \(error.localizedDescription)")
            return nil
        }
    }

    private func syncHistory() -> [NewPumpEvent] {
        var hasHistoryModeBeenActivate = false
        do {
            let activateHistoryModePacket =
                generatePacketGeneralSetHistoryUploadMode(options: PacketGeneralSetHistoryUploadMode(mode: 1))
            let activateHistoryModeResult = try bluetooth.writeMessage(activateHistoryModePacket)
            guard activateHistoryModeResult.success else {
                return []
            }

            hasHistoryModeBeenActivate = true

            let fetchHistoryPacket =
                generatePacketHistoryAll(options: PacketHistoryBase(from: state.lastStatusPumpDateTime, usingUtc: state.usingUtc))
            let fetchHistoryResult = try bluetooth.writeMessage(fetchHistoryPacket)
            guard fetchHistoryResult.success else {
                return []
            }

            let deactivateHistoryModePacket =
                generatePacketGeneralSetHistoryUploadMode(options: PacketGeneralSetHistoryUploadMode(mode: 0))
            _ = try bluetooth.writeMessage(deactivateHistoryModePacket)

            guard let list = fetchHistoryResult.data as? [HistoryItem] else {
                return []
            }

            var events: [NewPumpEvent] = []
            for item in list {
                switch item.code {
                case HistoryCode.RECORD_TYPE_ALARM:
                    events.append(NewPumpEvent(
                        date: item.timestamp,
                        dose: nil,
                        raw: item.raw,
                        title: "Alarm: \(getAlarmMessage(param8: item.alarm))",
                        type: .alarm,
                        alarmType: PumpAlarmType.fromParam8(item.alarm)
                    ))

                case HistoryCode.RECORD_TYPE_BOLUS:
                    if reconcilePendingBolus(with: item, into: &events) {
                        break
                    }

                    // Respect the user's opt-out of reporting new pump-history boluses.
                    if state.isBolusSyncDisabled {
                        break
                    }

                    // Loop already reported this bolus (it appears in history after Loop finalised
                    // it), so skip it and avoid double-counting (§7 reconciliation).
                    if isLoopInitiatedBolus(item.timestamp) {
                        break
                    }

                    // Otherwise it's a bolus the user made directly on the pump.
                    events.append(NewPumpEvent.bolus(
                        dose: DoseEntry.bolus(
                            units: item.value!,
                            deliveredUnits: item.value!,
                            duration: item.durationInMin! * 60,
                            activationType: .manualNoRecommendation,
                            insulinType: state.insulinType,
                            startDate: item.timestamp,
                            wasProgrammedByPumpUI: true
                        ),
                        date: item.timestamp
                    ))

                case HistoryCode.RECORD_TYPE_SUSPEND:
                    if item.value! == 1 {
                        events.append(NewPumpEvent.suspend(dose: DoseEntry.suspend(suspendDate: item.timestamp)))
                    } else {
                        events.append(NewPumpEvent.resume(
                            dose: DoseEntry.resume(insulinType: state.insulinType, resumeDate: item.timestamp),
                            date: item.timestamp
                        ))
                    }

                case HistoryCode.RECORD_TYPE_PRIME:
                    guard let value = item.value, value < 1 else {
                        // This is a tube refill, not a canulla refill
                        break
                    }

                    if state.cannulaDate == nil {
                        state.cannulaDate = item.timestamp
                    } else if let cannulaDate = state.cannulaDate, item.timestamp > cannulaDate {
                        state.cannulaDate = item.timestamp
                    }

                    events.append(NewPumpEvent(
                        date: item.timestamp,
                        dose: nil,
                        raw: item.raw,
                        title: "Prime \(value)U",
                        type: .replaceComponent(componentType: .infusionSet),
                        alarmType: nil
                    ))
                    events.append(NewPumpEvent(
                        date: item.timestamp,
                        dose: nil,
                        raw: item.raw,
                        title: "Prime \(value)U",
                        type: .prime,
                        alarmType: nil
                    ))

                case HistoryCode.RECORD_TYPE_REFILL:
                    if state.reservoirDate == nil {
                        state.reservoirDate = item.timestamp
                    } else if let reservoirDate = state.reservoirDate, item.timestamp > reservoirDate {
                        state.reservoirDate = item.timestamp
                    }

                    events.append(NewPumpEvent(
                        date: item.timestamp,
                        dose: nil,
                        raw: item.raw,
                        title: "Rewind \(item.value ?? 0)U",
                        type: .rewind,
                        alarmType: nil
                    ))
                    events.append(NewPumpEvent(
                        date: item.timestamp,
                        dose: nil,
                        raw: item.raw,
                        title: "Rewind \(item.value ?? 0)U",
                        type: .replaceComponent(componentType: .reservoir),
                        alarmType: nil
                    ))

                default:
                    break
                }
            }

            return events

        } catch {
            log.error("Failed to sync history. Error: \(error.localizedDescription)")
            if hasHistoryModeBeenActivate {
                do {
                    let deactivateHistoryModePacket =
                        generatePacketGeneralSetHistoryUploadMode(options: PacketGeneralSetHistoryUploadMode(mode: 0))
                    _ = try bluetooth.writeMessage(deactivateHistoryModePacket)
                } catch {}
            }
            return []
        }
    }

    func getTempBasalEvent(endDate: Date? = nil) -> NewPumpEvent? {
        guard state.basalDeliveryOrdinal == .tempBasal,
              let unitsPerHour = state.tempBasalUnits,
              let duration = state.tempBasalDuration
        else {
            return nil
        }

        // A temp basal that has run its full duration is reported as finalized (immutable, with a
        // real endDate and deliveredUnits) rather than silently dropped. Its raw identity is stable
        // (rate + start date), so this updates the existing mutable entry in Loop rather than
        // duplicating it (PumpManagerDoseReporting.md §3/§4).
        let expired = endDate == nil && state.tempBasalEndsAt <= Date.now
        let effectiveEnd = endDate ?? state.tempBasalEndsAt

        return NewPumpEvent.tempBasal(
            dose: DoseEntry.tempBasal(
                absoluteUnit: unitsPerHour,
                duration: duration,
                insulinType: state.insulinType,
                startDate: state.basalDeliveryDate,
                endDate: (endDate != nil || expired) ? effectiveEnd : nil
            ),
            date: state.basalDeliveryDate
        )
    }

    /// A mutable bolus still awaiting reconciliation (e.g. after a BLE drop or app restart). Re-report
    /// it on every sync so Loop does not purge it, until pump history reconciles and finalizes it.
    private func getPendingBolusEvent() -> NewPumpEvent? {
        guard let doseEntry = state.bolusDose else {
            return nil
        }

        let dose = doseEntry.toDoseEntry(endDate: nil)
        return NewPumpEvent.bolus(dose: dose, date: dose.startDate)
    }

    /// Width of the window used to decide whether a pump-history bolus corresponds to a Loop-commanded
    /// bolus (either one still pending, or one Loop already finalized). Chosen generously to tolerate
    /// clock skew while still only matching a discrete large event.
    private var bolusReconciliationWindow: TimeInterval {
        .minutes(4)
    }

    /// Remember that a Loop command started a bolus, so its later appearance in pump history is not
    /// double-counted. Pruned to bound memory/persistence growth.
    func recordLoopInitiatedBolus(_ startDate: Date) {
        state.loopInitiatedBolusStartDates.append(startDate)
        state.loopInitiatedBolusStartDates.removeAll { Date.now.timeIntervalSince($0) > .hours(1) }
    }

    private func isLoopInitiatedBolus(_ timestamp: Date) -> Bool {
        state.loopInitiatedBolusStartDates.contains {
            abs(timestamp.timeIntervalSince($0)) <= bolusReconciliationWindow
        }
    }

    /// Try to reconcile a still-pending Loop-commanded bolus against a pump-history bolus record.
    /// On a match, finalizes the pending dose with the pump's true delivered amount and emits a single
    /// event using the dose's stable identity, clearing the pending state. Returns `true` if this
    /// history record was consumed (so the caller must not also emit a separate pump-UI bolus).
    private func reconcilePendingBolus(with item: HistoryItem, into events: inout [NewPumpEvent]) -> Bool {
        guard let doseEntry = state.bolusDose,
              let delivered = item.value
        else {
            return false
        }

        // Match by the bolus start time. A pending dose interrupted by a BLE drop is the same physical
        // delivery as the later history record, so they must share a start time within the window.
        guard abs(item.timestamp.timeIntervalSince(doseEntry.startDate)) <= bolusReconciliationWindow else {
            return false
        }

        // The pump is the source of truth for what was actually delivered (§10).
        doseEntry.deliveredUnits = min(delivered, doseEntry.value)
        let endDate = item.timestamp.addingTimeInterval((item.durationInMin ?? 0) * 60)
        let dose = doseEntry.toDoseEntry(endDate: endDate)

        events.append(NewPumpEvent.bolus(dose: dose, date: dose.startDate))
        log.info("Reconciled pending bolus with pump history: \(dose.deliveredUnits ?? 0)U delivered")

        doseReporter = nil
        state.bolusDose = nil

        return true
    }
}
