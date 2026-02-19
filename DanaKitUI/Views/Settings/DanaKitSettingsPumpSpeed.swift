import LoopKitUI
import SwiftUI

struct DanaKitSettingsPumpSpeed: View {
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>

    let speedsAllowed = BolusSpeed.all()
    @State var value: Int

    var didChange: ((BolusSpeed) -> Void)?

    var body: some View {
        VStack(alignment: .leading) {
            VStack(alignment: .leading) {
                List {
                    Section(header: SectionHeader(label: LocalizedString(
                        "Select the bolus delivery speed",
                        comment: "Dana delivery speed body"
                    ))) {
                        CheckmarkListItem(
                            title: Text(BolusSpeed.speed12.format()),
                            description: Text(""),
                            isSelected: Binding(
                                get: { self.value == 0 },
                                set: { isSelected in
                                    if isSelected {
                                        self.value = 0
                                    }
                                }
                            )
                        )
                        CheckmarkListItem(
                            title: Text(BolusSpeed.speed30.format()),
                            description: Text(""),
                            isSelected: Binding(
                                get: { self.value == 1 },
                                set: { isSelected in
                                    if isSelected {
                                        self.value = 1
                                    }
                                }
                            )
                        )
                        CheckmarkListItem(
                            title: Text(BolusSpeed.speed60.format()),
                            description: Text(""),
                            isSelected: Binding(
                                get: { self.value == 2 },
                                set: { isSelected in
                                    if isSelected {
                                        self.value = 2
                                    }
                                }
                            )
                        )
                    }
                }
            }
            
            Spacer()

            ContinueButton(action: {
                didChange?(BolusSpeed(rawValue: UInt8(value))!)

                // Go back action
                presentationMode.wrappedValue.dismiss()
            })
        }
        .edgesIgnoringSafeArea(.bottom)
        .navigationBarHidden(false)
        .navigationTitle(LocalizedString("Delivery speed", comment: "Title for delivery speed"))
    }
}

#Preview {
    DanaKitSettingsPumpSpeed(value: 0)
}
