//
//  DanaKitDebugView.swift
//  DanaKit
//
//  Created by Bastiaan Verhaar on 18/12/2023.
//  Copyright © 2023 Randall Knutson. All rights reserved.
//

import SwiftUI
import os.log

struct DanaKitDebugView: View {
    @Environment(\.openURL) var openURL
    @ObservedObject var viewModel: DanaKitDebugViewModel
    
    var body: some View {
        VStack {
            HStack {
                Button("Scan", action: viewModel.scan)
                    .frame(width: 100, height: 100)

                Button("Connect", action: viewModel.connect)
                    .disabled(viewModel.scannedDevices.count == 0)
                    .frame(width: 100, height: 100)
            }
            
            HStack {
                Button("Do bolus", action: viewModel.bolusModal)
                    .disabled(viewModel.isConnected == false)
                    .frame(width: 100, height: 100)

                Button("Stop bolus", action: viewModel.stopBolus)
                    .disabled(viewModel.isConnected == false)
                    .frame(width: 100, height: 100)
            }
            
            HStack {
                Button("temp basal", action: viewModel.tempBasalModal)
                    .disabled(viewModel.isConnected == false)
                    .frame(width: 100, height: 100)

                Button("Stop temp basal", action: viewModel.stopTempBasal)
                    .disabled(viewModel.isConnected == false)
                    .frame(width: 100, height: 100)
            }
            
            HStack {
                Button("Basal", action: viewModel.basal)
                    .disabled(viewModel.isConnected == false)
                    .frame(width: 100, height: 100)

                Button("Disconnect", action: viewModel.disconnect)
                    .disabled(viewModel.isConnected == false)
                    .frame(width: 100, height: 100)
            }
            
            HStack {
                Button("Share logs", action: shareLogs)
                    .frame(width: 100, height: 100)
            }
        }
        .alert("Device found!",
               isPresented: $viewModel.isPresentingScanAlert,
               presenting: viewModel.messageScanAlert,
               actions: { detail in
                Button("No", action: {})
                Button("Yes", action: viewModel.connect)
               },
               message: { detail in Text(detail) }
        )
        .alert("Error while starting scanning for devices...",
               isPresented: $viewModel.isPresentingScanningErrorAlert,
               presenting: viewModel.scanningErrorMessage,
               actions: { detail in
                Button("Oke", action: {})
               },
               message: { detail in Text(detail) }
        )
        .alert("Dana-RS v3 found!",
               isPresented: $viewModel.isPresentingPincodeAlert,
               presenting: viewModel.messagePincodeAlert,
               actions: { detail in
                TextField("Code 1", text: $viewModel.pin1)
                TextField("Code 2", text: $viewModel.pin2)
                Button("Cancel", action: {})
                Button("Contiue", action: viewModel.danaRsPincode)
               },
               message: { detail in Text(detail) }
        )
        .alert("ERROR: Failed to pair device",
               isPresented: $viewModel.isPresentingForgetBleAlert,
               actions: {
                Button("Oke", action: {})
               },
               message: { Text("Failed to pair to " + viewModel.connectedDeviceName + ". Please go to your bluetooth settings, forget this device, and try again") }
        )
        .alert("DEBUG: Bolus action",
               isPresented: $viewModel.isPresentingBolusAlert,
               actions: {
                Button("No", action: {})
                Button("Yes", action: viewModel.bolus)
               },
               message: { Text("Are you sure you want to bolus 5E?") }
        )
        .alert("DEBUG: Temp basal action",
               isPresented: $viewModel.isPresentingTempBasalAlert,
               actions: {
                Button("No", action: {})
                Button("Yes", action: viewModel.tempBasal)
               },
               message: { Text("Are you sure you want to set the temp basal to 200% for 1 hour?") }
        )
    }
    
    func shareLogs() {
        guard let logging = viewModel.getLogs().addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return
        }
        
        let mailto = "mailto:verhaar.bastiaan@gmail.com?subject=Dana%20logs&body=" + logging
        guard let url = URL(string: mailto) else {
            return
        }
        
        openURL(url)
    }
}

#Preview {
    DanaKitDebugView(viewModel: DanaKitDebugViewModel())
}
