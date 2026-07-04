import LoopKit
import LoopKitUI
import SwiftUI

struct DanaKitSettingsView: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.guidanceColors) private var guidanceColors
    @Environment(\.dismissAction) private var dismiss
    @Environment(\.insulinTintColor) var insulinTintColor

    @ObservedObject var viewModel: DanaKitSettingsViewModel
    @State private var isSharePresented: Bool = false

    var supportedInsulinTypes: [InsulinType]
    var imageName: String

    var removePumpManagerActionSheet: ActionSheet {
        ActionSheet(
            title: Text("Remove Pump", comment: "Title for Dana-i/RS PumpManager deletion action sheet."),
            message: Text(
                "Are you sure you want to stop using Dana-i/RS?",
                comment: "Message for Dana-i/RS PumpManager deletion action sheet"
            ),
            buttons: [
                .destructive(Text(
                    "Delete pump",
                    comment: "Button text to confirm Dana-i/RS PumpManager deletion"
                )) {
                    viewModel.stopUsingDana()
                },
                .cancel()
            ]
        )
    }

    var syncPumpTime: ActionSheet {
        ActionSheet(
            title: Text("Time Change Detected", comment: "Title for pod sync time action sheet."),
            message: Text(
                "The time on your pump is different from the current time. Do you want to update the time on your pump to the current time?",
                comment: "Message for pod sync time action sheet"
            ),
            buttons: [
                .default(Text("Yes, Sync to Current Time", comment: "Button text to confirm pump time sync")) {
                    self.viewModel.syncPumpTime()
                },
                .cancel(Text("No, Keep Pump As Is", comment: "Button text to cancel pump time sync"))
            ]
        )
    }

    var blindReservoirCannulaRefill: ActionSheet {
        ActionSheet(title: Text("Type of refill", comment: "Title for refill action"), buttons: [
            .default(Text("Cannula only", comment: "Button text to cannula only")) {
                viewModel.navigateToRefillView(true)
            },
            .default(Text("Reservoir and cannula", comment: "Button text to Reservoir and cannula")) {
                viewModel.navigateToRefillView(false)
            },
            .cancel(Text("Cancel", comment: "Button text to cancel"))
        ])
    }

    var silentTone: ActionSheet {
        ActionSheet(
            title: Text("Toggle silent tone?", comment: "Title for silent tone action sheet"),
            buttons: [
                .default(viewModel.silentTone ? Text("Yes, Disable silent tones",
                            comment: "Button text to disable silent tone"
                        ) :
                            Text("Yes, Enable silent tones", comment: "Button text to enable silent tone")
                ) {
                    self.viewModel.toggleSilentTone()
                },
                .cancel(Text("No, Keep as is", comment: "Button text to cancel silent tone"))
            ]
        )
    }

    var bleModeSwitch: ActionSheet {
        ActionSheet(
            title: Text("Toggle Bluetooth mode", comment: "Title for bluetooth mode action sheet"),
            message: Text(
                "WARNING: Please don't use this until you've read the documentation",
                comment: "Warning message continuous mode"
            ),
            buttons: [
                .default(Text(
                    "What is this?",
                    comment: "Button text to get help about Continuous mode"
                )) {
                    openURL(URL(string: "https://loopkit.github.io/loopdocs/troubleshooting/dana-faq/#q-help-i-frequently-encounter-signal-loss-or-orange-loops")!)
                },
                .default(viewModel.isUsingContinuousMode ? Text("Yes, Switch to interactive mode",
                            comment: "Button text to disable continuous mode"
                        ) :
                            Text(
                            "Yes, Switch to continuous mode",
                            comment: "Button text to enable continuous mode"
                        )
                ) {
                    self.viewModel.toggleBleMode()
                },
                .cancel(Text("No, Keep as is", comment: "Button text to cancel silent tone"))
            ]
        )
    }

    var disableBolusSync: ActionSheet {
        ActionSheet(
            title: viewModel.isBolusSyncingDisabled ? Text(
                "Re-enable bolus syncing?",
                comment: "Title for bolus syncing disable action sheet"
            ) : Text("Disable bolus syncing?", comment: "Title for bolus syncing disable action sheet"),
            buttons: [
                .default(viewModel.isBolusSyncingDisabled ? Text("Yes, re-enable bolus syncing",
                            comment: "Button text to re-enable bplus syncing"
                        ) :
                            Text(
                            "Yes, disable bolus syncing",
                            comment: "Button text to disable bolus syncing"
                        )
                ) {
                    self.viewModel.toggleBolusSyncing()
                },
                .cancel(Text("No, Keep as is", comment: "Button text to cancel silent tone"))
            ]
        )
    }

    var disconnectReminder: ActionSheet {
        ActionSheet(
            title: Text("Set reminder for disconnect", comment: "Title disconnect reminder sheet"),
            message: Text(
                "Do you wish to receive a notification when the pump is longer disconnected for a specific time?",
                comment: "body disconnect reminder sheet"
            ),
            buttons: [
                .default(Text("Yes, 5 minutes", comment: "Button text to 5 min")) {
                    viewModel.scheduleDisconnectNotification(.minutes(5))
                },
                .default(Text("Yes, 15 minutes", comment: "Button text to 15 min")) {
                    viewModel.scheduleDisconnectNotification(.minutes(15))
                },
                .default(Text("Yes, 30 minutes", comment: "Button text to 30 min")) {
                    viewModel.scheduleDisconnectNotification(.minutes(30))
                },
                .default(Text("Yes, 1 hour", comment: "Button text to 1h")) {
                    viewModel.scheduleDisconnectNotification(.minutes(60))
                },
                .default(Text("No, just disconnect", comment: "Button text to just disconnect")) {
                    viewModel.forceDisconnect()
                },
                .cancel(Text("Cancel", comment: "Button text to cancel"))
            ]
        )
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Spacer()
                    Image(uiImage: UIImage(named: imageName, in: Bundle(for: DanaKitHUDProvider.self), compatibleWith: nil)!)
                        .resizable()
                        .scaledToFit()
                        .padding(.horizontal)
                        .frame(height: 200)
                    Spacer()
                }

                HStack(alignment: .top) {
                    deliveryStatus
                    Spacer()
                    reservoirStatus
                }
                .padding(.bottom, 5)

                if viewModel.showPumpTimeSyncWarning {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Time Change Detected", comment: "title for time change detected notice")
                            .font(Font.subheadline.weight(.bold))
                        Text(
                            "The time on your pump is different from the current time. Your pump’s time controls your scheduled therapy settings. Scroll down to Pump Time row to review the time difference and configure your pump.",
                            comment: "description for time change detected notice"
                        )
                            .font(Font.footnote.weight(.semibold))
                    }.padding(.vertical, 8)
                }
            }

            Section {
                Button(action: {
                    viewModel.suspendResumeButtonPressed()
                }) {
                    HStack {
                        Text($viewModel.basalButtonText.wrappedValue)
                        Spacer()
                        if viewModel.isUpdatingPumpState {
                            ActivityIndicator(isAnimating: .constant(true), style: .medium)
                        }
                    }
                }
                .disabled(viewModel.isUpdatingPumpState || viewModel.isSyncing)

                if viewModel.isTempBasal {
                    Button(action: {
                        viewModel.stopTempBasal()
                    }) {
                        HStack {
                            Text("Stop temp basal", comment: "Dana settings stop temp basal")
                            Spacer()
                            if viewModel.isUpdatingPumpState {
                                ActivityIndicator(isAnimating: .constant(true), style: .medium)
                            }
                        }
                    }
                    .disabled(viewModel.isUpdatingPumpState || viewModel.isSyncing)
                }

                Button(action: {
                    viewModel.syncData()
                }) {
                    HStack {
                        Text("Sync pump data", comment: "DanaKit sync pump")
                        Spacer()
                        if viewModel.isSyncing {
                            ActivityIndicator(isAnimating: .constant(true), style: .medium)
                        }
                    }
                }
                .disabled(viewModel.isUpdatingPumpState || viewModel.isSyncing)

                if viewModel.isUsingContinuousMode {
                    if !viewModel.isConnected {
                        Button(action: {
                            viewModel.reconnect()
                        }) {
                            HStack {
                                Text("Reconnect to pump", comment: "DanaKit reconnect")
                                Spacer()
                                if viewModel.isTogglingConnection {
                                    ActivityIndicator(isAnimating: .constant(true), style: .medium)
                                }
                            }
                        }
                        .disabled(viewModel.isTogglingConnection)
                    } else {
                        Button(action: {
                            viewModel.showingDisconnectReminder = true
                        }) {
                            HStack {
                                Text("Disconnect from pump", comment: "DanaKit disconnect")
                                Spacer()
                                if viewModel.isTogglingConnection {
                                    ActivityIndicator(isAnimating: .constant(true), style: .medium)
                                }
                            }
                        }
                        .disabled(viewModel.isTogglingConnection)
                        .actionSheet(isPresented: $viewModel.showingDisconnectReminder) {
                            disconnectReminder
                        }
                    }

                    HStack {
                        Text("Status", comment: "Text for status")
                            .foregroundColor(Color.primary)
                        Spacer()
                        HStack(spacing: 10) {
                            continuousConnectionStatusText
                            continuousConnectionStatusIcon
                        }
                    }
                }

                HStack {
                    Text("Last sync", comment: "Text for last sync")
                        .foregroundColor(Color.primary)
                    Spacer()
                    Text(String(viewModel.formatDate(viewModel.lastSync)))
                        .foregroundColor(.secondary)
                }

                if let reservoirAge = viewModel.reservoirAge {
                    HStack {
                        Text("Insulin age", comment: "Text for reservoir age")
                            .foregroundColor(Color.primary)
                        Spacer()
                        Text(String(reservoirAge))
                            .foregroundColor(.secondary)
                    }
                    .onLongPressGesture(perform: {
                        viewModel.updateReservoirAge()
                    })
                }

                if let cannulaAge = viewModel.cannulaAge {
                    HStack {
                        Text("Cannula age", comment: "Text for cannula age")
                            .foregroundColor(Color.primary)
                        Spacer()
                        Text(String(cannulaAge))
                            .foregroundColor(.secondary)
                    }
                    .onLongPressGesture(perform: {
                        viewModel.updateCannulaAge()
                    })
                }

                if let batteryAge = viewModel.batteryAge {
                    HStack {
                        Text("Battery age", comment: "Text for battery age")
                            .foregroundColor(Color.primary)
                        Spacer()
                        Text(String(batteryAge))
                            .foregroundColor(.secondary)
                    }
                    .onLongPressGesture(perform: {
                        viewModel.updateBatteryAge()
                    })
                }
            }

            Section(header: SectionHeader(label: String(localized:
                "Configuration",
                comment: "The title of the configuration section in DanaKit settings"
            )))
                {
                    NavigationLink(destination: InsulinTypeView(
                        initialValue: viewModel.insulinType,
                        supportedInsulinTypes: supportedInsulinTypes,
                        didConfirm: viewModel.didChangeInsulinType
                    )) {
                        HStack {
                            Text("Insulin Type", comment: "Text for confidence reminders navigation link")
                                .foregroundColor(Color.primary)
                            Spacer()
                            Text(viewModel.insulinType.brandName)
                                .foregroundColor(.secondary)
                        }
                    }
                    NavigationLink(destination: DanaKitSettingsPumpSpeed(
                        value: Int(viewModel.bolusSpeed.rawValue),
                        didChange: viewModel.didBolusSpeedChanged
                    )) {
                        HStack {
                            Text("Delivery speed", comment: "Title for delivery speed")
                                .foregroundColor(Color.primary)
                            Spacer()
                            Text(viewModel.bolusSpeed.format())
                                .foregroundColor(.secondary)
                        }
                    }
                    NavigationLink(destination: viewModel.userOptionsView) {
                        Text("User options", comment: "Title for user options")
                            .foregroundColor(Color.primary)
                    }
                    Button(action: {
                        viewModel.showingBlindReservoirCannulaRefill = true
                    }) {
                        HStack {
                            Text("Reservoir/cannula refill", comment: "Title for reservoir/cannula refill")
                            Spacer()
                            NavigationLink(
                                destination: viewModel.refillView,
                                isActive: $viewModel.showingReservoirCannulaRefillView
                            ) {
                                EmptyView() }
                                .hidden()
                                .frame(width: 0, height: 0)
                            Image(systemName: "chevron.right")
                                .font(.system(size: UIFont.systemFontSize, weight: .medium))
                                .opacity(0.35)
                        }
                        .foregroundColor(Color.primary)
                    }
                    .actionSheet(isPresented: $viewModel.showingBlindReservoirCannulaRefill) {
                        blindReservoirCannulaRefill
                    }
                }

            Section(header: SectionHeader(label: String(localized:
                "Pump information",
                comment: "The title of the pump information section in DanaKit settings"
            ))) {
                HStack {
                    Text("Pump name", comment: "Text for Dana pump name")
                        .foregroundColor(Color.primary)
                    Spacer()
                    Text(viewModel.deviceName ?? "")
                        .foregroundColor(.secondary)
                }
                .onLongPressGesture(perform: {
                    viewModel.showingSilentTone = true
                })
                .actionSheet(isPresented: $viewModel.showingSilentTone) {
                    silentTone
                }
                HStack {
                    Text("Hardware model", comment: "Text for hardware model")
                        .foregroundColor(Color.primary)
                    Spacer()
                    Text(String(viewModel.hardwareModel ?? 0))
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("Firmware version", comment: "Text for firmware version")
                        .foregroundColor(Color.primary)
                    Spacer()
                    Text(String(viewModel.firmwareVersion ?? 0))
                        .foregroundColor(.secondary)
                }
                .onLongPressGesture(perform: {
                    viewModel.showingBleModeSwitch = true
                })
                .actionSheet(isPresented: $viewModel.showingBleModeSwitch) {
                    bleModeSwitch
                }
                HStack {
                    Text("Basal profile", comment: "Text for Basal profile")
                        .foregroundColor(Color.primary)
                    Spacer()
                    Text(viewModel.transformBasalProfile(viewModel.basalProfileNumber))
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("Battery level", comment: "Text for Battery level")
                        .foregroundColor(Color.primary)
                    Spacer()
                    Text(String(viewModel.batteryLevel) + "%")
                        .foregroundColor(.secondary)
                }
                .onLongPressGesture(perform: {
                    viewModel.showingBolusSyncingDisabled = true
                })
                .actionSheet(isPresented: $viewModel.showingBolusSyncingDisabled) {
                    disableBolusSync
                }
            }

            Section(header: SectionHeader(label: String(localized:
                "Pump time",
                comment: "The title of the pump time section in DanaKit settings"
            ))) {
                HStack {
                    Text("Pump time", comment: "Text for pump time")
                        .foregroundColor(Color.primary)
                    Spacer()
                    if viewModel.showPumpTimeSyncWarning {
                        Image(systemName: "clock.fill")
                            .foregroundColor(guidanceColors.warning)
                    }
                    Text(String(viewModel.formatDate(viewModel.pumpTime)))
                        .foregroundColor(viewModel.showPumpTimeSyncWarning ? guidanceColors.warning : .secondary)
                }
                HStack {
                    Text("Checked at", comment: "Text for pump time synced at")
                        .foregroundColor(Color.primary)
                    Spacer()
                    Text(String(viewModel.formatDate(viewModel.pumpTimeSyncedAt)))
                        .foregroundColor(.secondary)
                }

                Toggle(
                    String(localized: "Nightly pump time sync", comment: "Text for Nightly pump time sync"),
                    isOn: $viewModel.nightlyPumpTimeSync
                )
                .onChange(of: viewModel.nightlyPumpTimeSync) { value in
                    viewModel.updateNightlyPumpTimeSync(value)
                }

                Button(action: {
                    viewModel.showingTimeSyncConfirmation = true
                }) {
                    Text("Manually sync Pump time", comment: "Label for syncing the time on the pump")
                        .foregroundColor(.accentColor)
                }
                .disabled(viewModel.isSyncing)
                .actionSheet(isPresented: $viewModel.showingTimeSyncConfirmation) {
                    syncPumpTime
                }
            }

            Section {
                Button(action: { self.isSharePresented = true }) {
                    Text("Share Dana pump logs", comment: "DanaKit share logs")
                }
                .sheet(isPresented: $isSharePresented, onDismiss: {}, content: {
                    ActivityViewController(activityItems: viewModel.getLogs())
                })

                Button(action: { viewModel.showingDeleteConfirmation = true }) {
                    Text("Delete Pump", comment: "Label for PumpManager deletion button")
                        .foregroundColor(guidanceColors.critical)
                }
                .actionSheet(isPresented: $viewModel.showingDeleteConfirmation) {
                    removePumpManagerActionSheet
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationBarItems(trailing: doneButton)
    }

    private var doneButton: some View {
        Button("Done", action: {
            dismiss()
        })
    }

    var reservoirStatus: some View {
        VStack(alignment: .trailing, spacing: 5) {
            Text("Insulin Remaining", comment: "Header for insulin remaining on pod settings screen")
                .foregroundColor(Color(UIColor.secondaryLabel))
            if let reservoirLevel = viewModel.reservoirLevel {
                HStack(alignment: .center, spacing: 5) {
                    ReservoirView(reservoirLevel: reservoirLevel, fillColor: reservoirColor(reservoirLevel))
                        .frame(width: 19, height: 26)
                    
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(viewModel.reservoirText(for: reservoirLevel))
                            .font(.system(size: 28))
                            .fontWeight(.heavy)
                            .fixedSize()
                        
                        Text("U", comment: "Insulin unit")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    var deliveryStatus: some View {
        VStack(alignment: .leading, spacing: 5) {
            deliverySectionTitle
                .foregroundColor(Color(UIColor.secondaryLabel))

            if viewModel.isSuspended {
                HStack(alignment: .center) {
                    Image(systemName: "pause.circle.fill")
                        .font(.system(size: 34))
                        .fixedSize()
                        .foregroundColor(viewModel.isSuspended ? guidanceColors.warning : Color.accentColor)
                    Text(
                        "Insulin\nSuspended",
                        comment: "Text shown in insulin delivery space when insulin suspended"
                    )
                        .fontWeight(.bold)
                        .fixedSize()
                }
            } else if let basalRate = $viewModel.basalRate.wrappedValue {
                HStack(alignment: .center) {
                    HStack(alignment: .lastTextBaseline, spacing: 3) {
                        Text(viewModel.basalRateFormatter.string(from: basalRate) ?? "")
                            .font(.system(size: 28))
                            .fontWeight(.heavy)
                            .fixedSize()
                        Text("U/hr", comment: "Units for showing temp basal rate")
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                HStack(alignment: .center) {
                    Image(systemName: "x.circle.fill")
                        .font(.system(size: 34))
                        .fixedSize()
                        .foregroundColor(guidanceColors.warning)
                    Text("Unknown", comment: "Text shown in basal rate space when delivery status is unknown")
                        .fontWeight(.bold)
                        .fixedSize()
                }
            }
        }
    }

    var continuousConnectionStatusText: some View {
        if viewModel.isTogglingConnection {
            if viewModel.isConnected {
                return Text("Disconnecting...", comment: "DanaKit disconnecting")
            } else {
                return Text("Reconnecting...", comment: "DanaKit reconnecting")
            }
        } else {
            if viewModel.isConnected {
                return Text("Connected", comment: "DanaKit connected")
            } else {
                return Text("Disconnected", comment: "DanaKit disconnected")
            }
        }
    }

    var continuousConnectionStatusIcon: some View {
        let color = viewModel.isTogglingConnection ? Color.orange : viewModel.isConnected ? Color.green : Color.red

        return Circle()
            .fill(color)
            .frame(width: 10, height: 10)
    }

    var deliverySectionTitle: Text {
        if viewModel.isSuspended {
            return Text("Insulin Delivery", comment: "Title of insulin delivery section")
        } else if viewModel.isTempBasal {
            return Text("Temp Basal", comment: "Pump Event title for UnfinalizedDose with doseType of .tempBasal")
        } else {
            return Text("Scheduled Basal", comment: "Title of insulin delivery section")
        }
    }

    private func reservoirColor(_ reservoirLevel: Double) -> Color {
        if reservoirLevel > viewModel.reservoirLevelWarning {
            return insulinTintColor
        }

        if reservoirLevel > 0 {
            return guidanceColors.warning
        }

        return guidanceColors.critical
    }
}

#Preview {
    DanaKitSettingsView(
        viewModel: DanaKitSettingsViewModel(nil, nil),
        supportedInsulinTypes: InsulinType.allCases,
        imageName: "danai"
    )
}
