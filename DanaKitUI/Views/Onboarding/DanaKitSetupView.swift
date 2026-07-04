import LoopKit
import LoopKitUI
import SwiftUI

struct DanaKitSetupView: View {
    @Environment(\.dismissAction) private var dismiss
    @State var value: Int = 2

    private let allowedOptions: [Int] = [1, 2]
    let nextAction: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading) {
            List {
                Section(header: SectionHeader(label: String(localized: "Choose your Dana pump", comment: "Onboarding subheader"))) {
                    CheckmarkListItem(
                        title: Text("Dana-i", comment: "dana-i option text for DanaKitSetupView"),
                        description: Text(
                            "The Dana-I insulin pump was first release in 2020 by manufacturer Sooil and is the latest in the series",
                            comment: "dana-i description"
                        ),
                        isSelected: Binding(
                            get: { self.value == 2 },
                            set: { isSelected in
                                if isSelected {
                                    self.value = 2
                                }
                            }
                        )
                    )
                    
                    CheckmarkListItem(
                        title: Text("DanaRS-v3", comment: "danaRS v3 option text for DanaKitSetupView"),
                        description: Text(
                            "The DanaRS insulin pump was first released in 2002. NOTE: only DanaRS pumps with firmware version 3 are supported",
                            comment: "danaRS v3 description"
                        ),
                        isSelected: Binding(
                            get: { self.value == 1 },
                            set: { isSelected in
                                if isSelected {
                                    self.value = 1
                                }
                            }
                        )
                    )
                }
                .buttonStyle(PlainButtonStyle()) // Disable row highlighting on selection
                
            }
            .insetGroupedListStyle()

            Spacer()

            ContinueButton(action: { nextAction(value) })
        }
        .edgesIgnoringSafeArea(.bottom)
        .navigationBarHidden(false)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: self.dismiss) {
                    Text("Cancel", comment: "Cancel button title")
                }
            }
        }
    }
}
