import LoopKit
import LoopKitUI
import SwiftUI

struct InsulinTypeView: View {
    @Environment(\.dismissAction) private var dismiss

    @State private var insulinType: InsulinType?
    private var supportedInsulinTypes: [InsulinType]
    private var didConfirm: (InsulinType) -> Void

    init(initialValue: InsulinType, supportedInsulinTypes: [InsulinType], didConfirm: @escaping (InsulinType) -> Void) {
        _insulinType = State(initialValue: initialValue)
        self.supportedInsulinTypes = supportedInsulinTypes
        self.didConfirm = didConfirm
    }

    func continueWithType(_ insulinType: InsulinType?) {
        if let insulinType = insulinType {
            didConfirm(insulinType)
        } else {
            assertionFailure()
        }
    }

    var body: some View {
        VStack(alignment: .leading) {
            List {
                Section(header: SectionHeader(label: LocalizedString(
                    "Select the type of insulin that you will be using in this pump",
                    comment: "Title text for insulin type confirmation page"
                ))) {
                    InsulinTypeChooser(insulinType: $insulinType, supportedInsulinTypes: supportedInsulinTypes)
                }
            }

            Spacer()

            ContinueButton(action: { self.continueWithType(insulinType) })
        }
        .edgesIgnoringSafeArea(.bottom)
        .navigationBarHidden(false)
        .navigationTitle(LocalizedString("Insulin Type", comment: "Title for insulin type"))
    }
}

struct InsulinTypeView_Previews: PreviewProvider {
    static var previews: some View {
        InsulinTypeView(initialValue: .novolog, supportedInsulinTypes: InsulinType.allCases, didConfirm: { _ in })
    }
}
