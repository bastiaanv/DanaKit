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

    public var viewModel: DanaKitScanViewModel
    
    var body: some View {
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
    }
    
    @ViewBuilder
    private var content: some View {
        VStack(alignment: .leading, spacing: 2) {
            ScrollView {
                List (viewModel.scannedDevices) { result in
                    Text(result.device.name)
                }
                .listStyle(GroupedListStyle())
            }
        }
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
