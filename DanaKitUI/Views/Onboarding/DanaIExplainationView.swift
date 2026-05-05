import LoopKitUI
import SwiftUI

struct DanaIExplainationView: View {
    @Environment(\.dismissAction) private var dismiss
    @Environment(\.appName) var appName

    let nextAction: () -> Void

    var body: some View {
        VStack(alignment: .leading) {
            List {
                Section {
                    Text(String(
                        format: String(
                            localized:
                            "After setting up the insulin type and bolus speed, you will see all the found Dana pumps. Select the pump you want to link with %1$@.",
                            comment: "General subtext for dana (1: appName)"
                        ),
                        appName
                    ))

                    HStack {
                        Spacer()
                        Image(danaImage: "pairing_request")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 150)
                        Spacer()
                    }
                    .padding(.vertical, 10)

                    Text(String(
                        format: String(
                            localized:
                            "During the pairing process, your Dana-i will show a pairing prompt while your iPhone will show a prompt for a pairing code. On you pump, select OK and type the 6-digit code in screen on your iPhone. After that, %1$@ is ready to communicate with your Dana-i",
                            comment: "Subtext for dana-i (1: appName)"
                        ),
                        appName
                    ))
                }
            }

            Spacer()

            ContinueButton(action: nextAction)
        }
        .edgesIgnoringSafeArea(.bottom)
        .navigationBarHidden(false)
        .navigationTitle(String(localized: "Setting up Dana-i", comment: "Title for dana-i explaination"))
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: self.dismiss) {
                    Text("Cancel", comment: "Cancel button title")
                }
            }
        }
    }
}

#Preview {
    DanaIExplainationView(nextAction: {})
}
