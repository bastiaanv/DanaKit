import LoopKitUI
import SwiftUI

struct DanaKitPumpSpeed: View {
    @Environment(\.dismissAction) private var dismiss

    let speedsAllowed = BolusSpeed.all()
    @State var speedDefault = Int(BolusSpeed.speed12.rawValue)

    var next: ((BolusSpeed) -> Void)?

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
                                get: { self.speedDefault == 0 },
                                set: { isSelected in
                                    if isSelected {
                                        self.speedDefault = 0
                                    }
                                }
                            )
                        )
                        CheckmarkListItem(
                            title: Text(BolusSpeed.speed30.format()),
                            description: Text(""),
                            isSelected: Binding(
                                get: { self.speedDefault == 1 },
                                set: { isSelected in
                                    if isSelected {
                                        self.speedDefault = 1
                                    }
                                }
                            )
                        )
                        CheckmarkListItem(
                            title: Text(BolusSpeed.speed60.format()),
                            description: Text(""),
                            isSelected: Binding(
                                get: { self.speedDefault == 2 },
                                set: { isSelected in
                                    if isSelected {
                                        self.speedDefault = 2
                                    }
                                }
                            )
                        )
                    }
                }
            }
            
            Spacer()

            ContinueButton(action: {
                guard let speed = BolusSpeed(rawValue: UInt8($speedDefault.wrappedValue)) else {
                    return
                }

                next?(speed)
            })
        }
        .edgesIgnoringSafeArea(.bottom)
        .navigationBarHidden(false)
        .navigationTitle(LocalizedString("Delivery speed", comment: "Title for delivery speed"))
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(LocalizedString("Cancel", comment: "Cancel button title"), action: {
                    self.dismiss()
                })
            }
        }
    }
}

#Preview {
    DanaKitPumpSpeed()
}
