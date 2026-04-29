import LoopKitUI
import SwiftUI

struct PickerView: View {
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>

    @State var value: Int

    private var currentValue: Binding<Int> {
        Binding(
            get: { value },
            set: { newValue in
                self.value = newValue
            }
        )
    }

    var allowedOptions: [Int]
    var formatter: (Int) -> String
    var didChange: ((Int) -> Void)?

    var title: Text
    var description: Text?

    var body: some View {
        VStack(alignment: .leading) {
            VStack(alignment: .leading) {
                title
                    .font(.title)
                    .bold()
                
                if let description {
                    description
                        .fixedSize(horizontal: false, vertical: true)
                }

                Divider()
                Spacer()

                ResizeablePicker(
                    selection: currentValue,
                    data: self.allowedOptions,
                    formatter: { formatter($0) }
                )
                .padding(.horizontal)

                Spacer()
            }
            .padding(.horizontal)

            ContinueButton(action: {
                didChange?(value)

                // Go back action
                presentationMode.wrappedValue.dismiss()
            })
        }
        .edgesIgnoringSafeArea(.bottom)
        .navigationBarHidden(false)
    }
}
