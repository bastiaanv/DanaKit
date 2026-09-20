import LoopKitUI
import SwiftUI

struct DanaKitUserSettingsView: View {
    @ObservedObject var viewModel: DanaKitUserSettingsViewModel
    
    @State var isEdittingReservoirWarning = false
    @State var isEdittingTimeFormat = false
    @State var isEdittingScroll = false
    @State var isEdittingBacklight = false
    @State var isEdittingLcd = false
    @State var isEdittingBeeps = false
    @State var isEdittingRefill = false

    @ViewBuilder var body: some View {
        VStack {
            List {
                Section {
                    valueRow(
                        labelValue: Text("Low reservoir reminder", comment: "Text for low reservoir reminder"),
                        statePicker: $isEdittingReservoirWarning,
                        valueValue: $viewModel.lowReservoirRate,
                        allowedOptions: Array(5 ... 40),
                        formatter: { String($0) + String(localized: "U", comment: "Insulin unit") }
                    )
                    
                    valueRow(
                        labelValue: Text("24h display", comment: "Text for 24h display"),
                        statePicker: $isEdittingTimeFormat,
                        valueValue: $viewModel.isTimeDisplay24H,
                        allowedOptions: [true, false],
                        formatter: { $0 ? String(localized: "24h notation", comment: "24h notation") : String(localized: "12h notation", comment: "12h notation") }
                    )
                    
                    valueRow(
                        labelValue: Text("Scroll function", comment: "Text for Scroll function"),
                        statePicker: $isEdittingScroll,
                        valueValue: $viewModel.isButtonScrollOnOff,
                        allowedOptions: [true, false],
                        formatter: { $0 ? String(localized: "On", comment: "text on") : String(localized: "Off", comment: "text off") }
                    )
                    
                    valueRow(
                        labelValue: Text("Backlight on time", comment: "backlightOnTime"),
                        statePicker: $isEdittingBacklight,
                        valueValue: $viewModel.backlightOnTimeInSec,
                        allowedOptions: Array(0 ... 48).map({ $0 * 5 }),
                        formatter: { String(format: String(localized: "%lld sec", comment: "second placeholder"), $0) }
                    )
                    
                    valueRow(
                        labelValue: Text("Lcd on time", comment: "lcdOnTime"),
                        statePicker: $isEdittingLcd,
                        valueValue: $viewModel.lcdOnTimeInSec,
                        allowedOptions: Array(0 ... 48).map({ $0 * 5 }),
                        formatter: { String(format: String(localized: "%lld sec", comment: "second placeholder"), $0) }
                    )
                    
                    valueRow(
                        labelValue: Text("Alarm beeps", comment: "beepAndAlarm"),
                        statePicker: $isEdittingBeeps,
                        valueValue: $viewModel.beepAndAlarm,
                        allowedOptions: [.both, .sound, .vibration],
                        formatter: { $0.title }
                    )
                    
                    valueRow(
                        labelValue: Text("Refill amount", comment: "refillAmount"),
                        statePicker: $isEdittingRefill,
                        valueValue: $viewModel.refillAmount,
                        allowedOptions: Array(0 ... 60).map({ $0 * 5 }),
                        formatter: { "\($0) \(String(localized: "U", comment: "Insulin unit")) " }
                    )
                }
            }
            Spacer()

            ContinueButton(
                text: String(localized: "Save", comment: "Text for save button"),
                loading: $viewModel.storingUseroption,
                action: { viewModel.storeUserOption() }
            )
        }
        .edgesIgnoringSafeArea(.bottom)
    }
    
    @ViewBuilder private func valueRow<T: Hashable>(
        labelValue: Text,
        statePicker: Binding<Bool>,
        valueValue: Binding<T>,
        allowedOptions: [T],
        formatter: @escaping (T) -> String
    ) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                labelValue
                    .foregroundStyle(statePicker.wrappedValue ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
                Spacer()
                Text(formatter(valueValue.wrappedValue))
                    .foregroundStyle(statePicker.wrappedValue ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
            }
            .onTapGesture {
                statePicker.wrappedValue.toggle()
            }

            if statePicker.wrappedValue {
                Picker(selection: valueValue) {
                    ForEach(allowedOptions, id: \.self) { item in
                        Text(formatter(item))
                    }
                } label: { EmptyView() }
                    .pickerStyle(.wheel)
            }
        }
    }
}
