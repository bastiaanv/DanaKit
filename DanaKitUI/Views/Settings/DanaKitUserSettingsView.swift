import LoopKitUI
import SwiftUI

struct DanaKitUserSettingsView: View {
    @ObservedObject var viewModel: DanaKitUserSettingsViewModel

    private var revervoirWarningView: PickerView {
        PickerView(
            value: Int(viewModel.lowReservoirRate),
            allowedOptions: Array(5 ... 40),
            formatter: { value in String(value) + String(localized: "U", comment: "Insulin unit") },
            didChange: { value in viewModel.lowReservoirRate = UInt8(value) },
            title: Text("Low reservoir reminder", comment: "Text for low reservoir reminder"),
            description: Text(
                "The pump reminds you when the amount of insulin in the pump reaches this level",
                comment: "Description for low reservoir reminder"
            )
        )
    }

    private var time24hView: PickerView {
        PickerView(
            value: viewModel.isTimeDisplay24H ? 1 : 0,
            allowedOptions: [0, 1],
            formatter: { value in
                value == 1 ? String(localized: "24h notation", comment: "24h notation") :
                    String(localized: "12h notation", comment: "12h notation") },
            didChange: { value in viewModel.isTimeDisplay24H = value == 1 },
            title: Text("24h display", comment: "Text for 24h display"),
            description: Text("Should time be display in 12h or 24h", comment: "Description for 24h display")
        )
    }

    private var buttonScrollOnOffView: PickerView {
        PickerView(
            value: viewModel.isButtonScrollOnOff ? 1 : 0,
            allowedOptions: [0, 1],
            formatter: { value in
                value == 1 ? String(localized: "On", comment: "text on") : String(localized: "Off", comment: "text off") },
            didChange: { value in viewModel.isButtonScrollOnOff = value == 1 },
            title: Text("Scroll function", comment: "Text for Scroll function")
        )
    }

    private var backlightOnTimeInSecView: PickerView {
        PickerView(
            value: Int(viewModel.backlightOnTimeInSec),
            allowedOptions: Array(0 ... 48).map({ $0 * 5 }),
            formatter: { value in "\(value) \(String(localized: "sec", comment: "text for second"))" },
            didChange: { value in viewModel.backlightOnTimeInSec = UInt8(value) },
            title: Text("Backlight on time", comment: "backlightOnTime")
        )
    }

    private var lcdOnTimeInSecView: PickerView {
        PickerView(
            value: Int(viewModel.lcdOnTimeInSec),
            allowedOptions: Array(0 ... 48).map({ $0 * 5 }),
            formatter: { value in "\(value) \(String(localized: "sec", comment: "text for second"))" },
            didChange: { value in viewModel.lcdOnTimeInSec = UInt8(value) },
            title: Text("Lcd on time", comment: "lcdOnTime")
        )
    }

    private var beepAlarmView: PickerView {
        PickerView(
            value: Int(viewModel.beepAndAlarm.rawValue),
            allowedOptions: BeepAlarmType.all(),
            formatter: beepFormatter,
            didChange: { value in viewModel.beepAndAlarm = BeepAlarmType(rawValue: UInt8(value)) ?? .sound },
            title: Text("Alarm beeps", comment: "beepAndAlarm")
        )
    }

    private var refillAmountView: PickerView {
        PickerView(
            value: Int(viewModel.refillAmount),
            allowedOptions: Array(0 ... 60).map({ $0 * 5 }),
            formatter: { value in "\(value) \(String(localized: "U", comment: "Insulin unit")) " },
            didChange: { value in viewModel.refillAmount = UInt16(value) },
            title: Text("Refill amount", comment: "refillAmount")
        )
    }

    @ViewBuilder var body: some View {
        VStack {
            List {
                NavigationLink(destination: revervoirWarningView) {
                    HStack {
                        Text("Low reservoir reminder", comment: "Text for low reservoir reminder")
                            .foregroundColor(Color.primary)
                        Spacer()
                        Text(String(viewModel.lowReservoirRate) + String(localized: "U", comment: "Insulin unit"))
                    }
                }
                NavigationLink(destination: time24hView) {
                    HStack {
                        Text("24h display", comment: "Text for 24h display")
                            .foregroundColor(Color.primary)
                        Spacer()
                        Text(
                            viewModel
                                .isTimeDisplay24H ? String(localized: "24h notation", comment: "24h notation") :
                                String(localized: "12h notation", comment: "12h notation")
                        )
                    }
                }
                NavigationLink(destination: buttonScrollOnOffView) {
                    HStack {
                        Text("Scroll function", comment: "Text for Scroll function")
                            .foregroundColor(Color.primary)
                        Spacer()
                        Text(
                            viewModel
                                .isButtonScrollOnOff ? String(localized: "On", comment: "text on") :
                                String(localized: "Off", comment: "text off")
                        )
                    }
                }
                NavigationLink(destination: backlightOnTimeInSecView) {
                    HStack {
                        Text("Backlight on time", comment: "backlightOnTime")
                            .foregroundColor(Color.primary)
                        Spacer()
                        Text("\(viewModel.backlightOnTimeInSec) \(String(localized: "sec", comment: "text for second"))")
                    }
                }
                NavigationLink(destination: lcdOnTimeInSecView) {
                    HStack {
                        Text("Lcd on time", comment: "lcdOnTime")
                            .foregroundColor(Color.primary)
                        Spacer()
                        Text("\(viewModel.lcdOnTimeInSec) \(String(localized: "sec", comment: "text for second"))")
                    }
                }
                NavigationLink(destination: beepAlarmView) {
                    HStack {
                        Text("Alarm beeps", comment: "beepAndAlarm")
                            .foregroundColor(Color.primary)
                        Spacer()
                        Text(beepFormatter(value: Int(viewModel.beepAndAlarm.rawValue)))
                    }
                }
                NavigationLink(destination: refillAmountView) {
                    HStack {
                        Text("Refill amount", comment: "refillAmount")
                            .foregroundColor(Color.primary)
                        Spacer()
                        Text(String(viewModel.refillAmount) + String(localized: "U", comment: "Insulin unit"))
                    }
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
        .navigationBarTitle(String(localized: "User options", comment: "Title for user options"))
    }

    private func beepFormatter(value: Int) -> String {
        switch value {
        case 1:
            return String(localized: "Sound", comment: "beepAndAlarm.sound")
        case 2:
            return String(localized: "Vibration", comment: "beepAndAlarm.vibration")
        case 3:
            return String(localized: "Both", comment: "beepAndAlarm.both")
        default:
            return ""
        }
    }
}
