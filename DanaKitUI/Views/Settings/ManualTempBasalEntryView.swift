import HealthKit
import LoopKit
import LoopKitUI
import SwiftUI

struct ManualTempBasalEntryView: View {
    @Environment(\.guidanceColors) var guidanceColors

    var currentScheduledBasal: Double
    var enactBasal: ((UInt16, TimeInterval, @escaping (PumpManagerError?) -> Void) -> Void)?
    var didCancel: (() -> Void)?

    @State private var rateEntered: UInt16 = 0
    @State private var durationEntered: TimeInterval = .hours(1)
    @State private var showPicker: Bool = false
    @State private var error: PumpManagerError?
    @State private var enacting: Bool = false
    @State private var showingErrorAlert: Bool = false
    @State private var showingMissingConfigAlert: Bool = false

    private let allowedRates: [UInt16] = Array(stride(from: 0, through: 200, by: 10))
    private let allowedDurations: [TimeInterval] = [.minutes(15), .minutes(30)]
        + stride(from: 1, through: 24, by: 1).map { TimeInterval.hours(Double($0)) }

    init(
        currentScheduledBasal: Double,
        enactBasal: ((UInt16, TimeInterval, @escaping (PumpManagerError?) -> Void) -> Void)? = nil,
        didCancel: (() -> Void)? = nil
    ) {
        self.currentScheduledBasal = currentScheduledBasal
        self.enactBasal = enactBasal
        self.didCancel = didCancel
    }

    private static let hourFormatter: QuantityFormatter = {
        let quantityFormatter = QuantityFormatter(for: .hour())
        quantityFormatter.numberFormatter.minimumFractionDigits = 0
        quantityFormatter.numberFormatter.maximumFractionDigits = 0
        quantityFormatter.unitStyle = .long
        return quantityFormatter
    }()

    private static let minuteFormatter: QuantityFormatter = {
        let formatter = QuantityFormatter(for: .minute())
        formatter.numberFormatter.minimumFractionDigits = 0
        formatter.numberFormatter.maximumFractionDigits = 0
        formatter.unitStyle = .long
        return formatter
    }()

    func formatDuration(_ duration: TimeInterval) -> String {
        if duration < TimeInterval.hours(1) {
            return ManualTempBasalEntryView.minuteFormatter
                .string(from: HKQuantity(unit: .minute(), doubleValue: duration.minutes)) ?? ""
        } else {
            return ManualTempBasalEntryView.hourFormatter
                .string(from: HKQuantity(unit: .hour(), doubleValue: duration.hours)) ?? ""
        }
    }

    var body: some View {
        NavigationView {
            VStack {
                List {
                    Section {
                        HStack {
                            Text("Rate", comment: "Label text for basal rate summary")
                            Spacer()
                            Text(
                                String(
                                    format:
                                    String(
                                        localized: "%@ for %@",
                                        comment: "Summary string for temporary basal rate configuration page"
                                    ),
                                    rateEntered.formatted(.percent),
                                    formatDuration(durationEntered)
                                )
                            )
                        }
                        HStack {
                            ResizeablePicker(
                                selection: $rateEntered,
                                data: allowedRates,
                                formatter: {
                                    String(
                                        format: String(localized: "%@ (%@ U/hr)", comment: "MTB rate"),
                                        $0.formatted(.percent),
                                        String(format: "%.2f", currentScheduledBasal * (Double($0) / 100))
                                    ) }
                            )
                            ResizeablePicker(
                                selection: $durationEntered,
                                data: allowedDurations,
                                formatter: { formatDuration($0) }
                            )
                        }
                        .frame(maxHeight: 162.0)
                        .alert(isPresented: $showingMissingConfigAlert, content: { missingConfigAlert })
                    } footer: {
                        Text(
                            "Your insulin delivery will not be automatically adjusted until the temporary basal rate finishes or is canceled.",
                            comment: "Description text on manual temp basal action sheet"
                        )
                    }
                }
                Button(action: {
                    enacting = true
                    enactBasal?(rateEntered, durationEntered) { error in
                        if let error = error {
                            self.error = error
                            showingErrorAlert = true
                        }
                        enacting = false
                    }
                }) {
                    HStack {
                        if enacting {
                            ProgressView()
                        } else {
                            Text("Set Temporary Basal", comment: "Button text for setting manual temporary basal rate")
                        }
                    }
                }
                .buttonStyle(ActionButtonStyle(.primary))
                .padding()
            }
            .navigationTitle(Text("Temporary Basal", comment: "Navigation Title for ManualTempBasalEntryView"))
            .navigationBarItems(trailing: cancelButton)
            .alert(isPresented: $showingErrorAlert, content: { errorAlert })
            .disabled(enacting)
        }
    }

    var errorAlert: SwiftUI.Alert {
        let errorMessage = errorMessage(error: error!)
        return SwiftUI.Alert(
            title: Text("Temporary Basal Failed", comment: "Alert title for a failure to set temporary basal"),
            message: errorMessage
        )
    }

    func errorMessage(error: PumpManagerError) -> Text {
        if let recovery = error.recoverySuggestion {
            return Text(String(
                format:
                String(
                    localized: "Unable to set a temporary basal rate: %@\n\n%@",
                    comment: "Alert format string for a failure to set temporary basal with recovery suggestion. (1: error description) (2: recovery text)"
                ),
                error.localizedDescription,
                recovery
            ))
        } else {
            return Text(String(
                format:
                String(
                    localized: "Unable to set a temporary basal rate: %@",
                    comment: "Alert format string for a failure to set temporary basal. (1: error description)"
                ),
                error.localizedDescription
            ))
        }
    }

    var missingConfigAlert: SwiftUI.Alert {
        SwiftUI.Alert(
            title: Text("Missing Config", comment: "Alert title for missing temp basal configuration"),
            message: Text(
                "This PumpManager has not been configured with a maximum basal rate because it was added before manual temp basal was a feature. Please set a new maximum basal rate.",
                comment: "Alert format string for missing temp basal configuration."
            )
        )
    }

    var cancelButton: some View {
        Button(action: {
            didCancel?()
        }) {
            Text("Cancel", comment: "Cancel button text in navigation bar on insert cannula screen")
        }
        .accessibility(identifier: "button_cancel")
    }
}
