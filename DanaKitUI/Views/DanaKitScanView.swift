//
//  DanaKitScanView.swift
//  DanaKit
//
//  Created by Bastiaan Verhaar on 28/12/2023.
//  Copyright © 2023 Randall Knutson. All rights reserved.
//

import SwiftUI
import LoopKitUI

struct DanaKitScanView: View {
    @Environment(\.isPresented) var isPresented
    @Environment(\.dismissAction) private var dismiss

    @ObservedObject var viewModel: DanaKitScanViewModel
    
    var body: some View {
        LoadingModal(isShowing: $viewModel.isConnecting, text: LocalizedString("Connecting to device", comment: "Dana-i/RS connecting alert title"), content:  {
            VStack(alignment: .leading) {
                title
                content
            }
            .padding(.horizontal)
            .navigationBarHidden(false)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(LocalizedString("Cancel", comment: "Cancel button title"), action: {
                        viewModel.stopScan()
                        self.dismiss()
                    })
                }
            }
            .onChange(of: isPresented) { newValue in
                if !newValue {
                    viewModel.stopScan()
                }
            }
            .alert(LocalizedString("ERROR: Failed to pair device", comment: "Dana-i invalid ble5 keys"),
                   isPresented: $viewModel.isPresentingBle5KeysError,
                   presenting: viewModel.connectedDeviceName,
                   actions: {_ in
                Button(action: {}, label: { Text(LocalizedString("Oke", comment: "Dana-i oke invalid ble5 keys")) })
            },
                   message: { deviceName in
                Text(
                    LocalizedString("Failed to pair to ", comment: "Dana-i failed to pair p1") +
                    deviceName +
                    LocalizedString(". Please go to your bluetooth settings, forget this device, and try again", comment: "Dana-i failed to pair p2")
                )
            }
            )
        })
    }
    
    @ViewBuilder
    private var content: some View {
        List ($viewModel.scannedDevices) { $result in
            Button(action: { viewModel.connect($result.wrappedValue) }) {
                HStack {
                    Text($result.name.wrappedValue)
                    Spacer()
                    NavigationLink.empty
                }
            }
            .buttonStyle(.plain)
        }
        .listStyle(.plain)
    }
    
    @ViewBuilder
    private var title: some View {
        HStack {
            Text(LocalizedString("Found Dana-i/RS pumps", comment: "Title for DanaKitScanView"))
                .font(.title)
                .bold()
            Spacer()
            ProgressView()
        }
    }
}

#Preview {
    DanaKitScanView(viewModel: DanaKitScanViewModel(nextStep: {}))
}
