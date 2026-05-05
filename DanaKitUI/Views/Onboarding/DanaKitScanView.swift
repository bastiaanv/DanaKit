import LoopKitUI
import SwiftUI

struct DanaKitScanView: View {
    @Environment(\.isPresented) var isPresented
    @Environment(\.dismissAction) private var dismiss

    @ObservedObject var viewModel: DanaKitScanViewModel

    var body: some View {
        VStack(alignment: .leading) {
            List {
                Section(header: SectionHeader(
                    label: !$viewModel.isConnecting.wrappedValue ?
                        String(localized: "Scanning", comment: "Scanning text") :
                        String(localized: "Connecting", comment: "Connecting text")
                )) {
                    ForEach($viewModel.scannedDevices) { $result in
                        Button(action: { viewModel.connect($result.wrappedValue) }) {
                            HStack {
                                Text($result.name.wrappedValue)
                                Spacer()
                                if !$viewModel.isConnecting.wrappedValue {
                                    NavigationLink.empty
                                } else if $result.name.wrappedValue == viewModel.connectingTo {
                                    ActivityIndicator(isAnimating: .constant(true), style: .medium)
                                }
                            }
                            .padding(.horizontal)
                        }
                        .disabled($viewModel.isConnecting.wrappedValue)
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .navigationBarHidden(false)
        .navigationTitle(String(localized: "Pairing", comment: "Title for DanaKitScanView"))
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    viewModel.stopScan()
                    self.dismiss()
                }) {
                    Text("Cancel", comment: "Cancel button title")
                }
            }
        }
        .onChange(of: isPresented) { newValue in
            if !newValue {
                viewModel.stopScan()
            }
        }
        .alert(
            String(localized: "Error while connecting to device", comment: "Connection error message"),
            isPresented: $viewModel.isConnectionError,
            presenting: $viewModel.connectionErrorMessage,
            actions: { _ in
                Button(action: {}) {
                    Text("Okay", comment: "label Okay")
                }
            },
            message: { detail in Text(detail.wrappedValue ?? "") }
        )
        .alert(
            String(localized: "Dana-RS v3 found!", comment: "Dana-RS v3 found"),
            isPresented: $viewModel.isPromptingPincode
        ) {
            Button(action: viewModel.cancelPinPrompt) {
                Text("Cancel", comment: "Cancel button title")
            }
            Button(action: viewModel.processPinPrompt) {
                Text("Okay", comment: "label Okay")
            }

            TextField(String(localized: "Pin 1", comment: "Dana-RS v3 pincode prompt pin 1"), text: $viewModel.pin1)
            TextField(String(localized: "Pin 2", comment: "Dana-RS v3 pincode prompt pin 2"), text: $viewModel.pin2)
        } message: {
            if let message = $viewModel.pinCodePromptError.wrappedValue {
                Text(message)
            }
        }
    }
}
