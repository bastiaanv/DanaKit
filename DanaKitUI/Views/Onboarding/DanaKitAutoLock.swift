import LoopKitUI
import SwiftUI

struct DanaKitAutoLock: View {
    @ObservedObject var viewModel: DanaKitAutoLockViewModel

    var body: some View {
        VStack(alignment: .leading) {
            List {
                Section(header: SectionHeader(label: String(
                    localized:
                    "Select the auto lock setting of your Dana-i2",
                    comment: "Dana-i2 auto lock body"
                ))) {
                    CheckmarkListItem(
                        title: Text("On", comment: "text on"),
                        description: Text("The pump locks its buttons automatically", comment: "Dana-i2 auto lock on"),
                        isSelected: Binding(
                            get: { viewModel.autoLock },
                            set: { isSelected in
                                if isSelected {
                                    viewModel.autoLock = true
                                }
                            }
                        )
                    )
                    CheckmarkListItem(
                        title: Text("Off", comment: "text off"),
                        description: Text("The pump does not lock its buttons", comment: "Dana-i2 auto lock off"),
                        isSelected: Binding(
                            get: { !viewModel.autoLock },
                            set: { isSelected in
                                if isSelected {
                                    viewModel.autoLock = false
                                }
                            }
                        )
                    )
                }

                if viewModel.failedAutoLock {
                    Label(
                        String(
                            localized: "Failed to set auto lock. Please try again",
                            comment: "Label for error Dana-i2 auto lock"
                        ),
                        systemImage: "exclamationmark.circle.fill"
                    )
                    .foregroundStyle(.red)
                }
            }

            Spacer()

            ContinueButton(loading: $viewModel.storingAutoLock, action: { viewModel.storeAutoLock() })
        }
        .edgesIgnoringSafeArea(.bottom)
        .navigationBarHidden(false)
    }
}
