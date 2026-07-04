import LoopKitUI
import SwiftUI

struct DanaRSv3Explaination: View {
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
                            "During the pairing process, your DanaRS v3 will show a pairing prompt while you iPhone will show a prompt for two pairing codes. On your pump, select OK and type the two codes on your iPhone. After that, %1$@ is ready to communicate with your DanaRS v3",
                            comment: "Subtext for danars v3 (1: appName)"
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
    DanaRSv3Explaination(nextAction: {})
}
