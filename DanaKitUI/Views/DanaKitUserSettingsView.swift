//
//  DanaKitUserSettingsView.swift
//  DanaKit
//
//  Created by Bastiaan Verhaar on 29/01/2024.
//  Copyright © 2024 Randall Knutson. All rights reserved.
//

import SwiftUI

struct DanaKitUserSettingsView: View {
    @Environment(\.isPresented) var isPresented
    @Environment(\.dismissAction) private var dismiss
    
    @ObservedObject var viewModel: DanaKitUserSettingsViewModel
    
    private var revervoirWarningView: PickerView {
        PickerView(
            currentOption: viewModel.lowReservoirLevel,
            allowedOptions: Array(5...40),
            formatter: { value in String(value) + LocalizedString("U", comment: "Insulin unit")},
            title: LocalizedString("Low reservoir reminder", comment: "Text for low reservoir reminder"),
            description: LocalizedString("The pump reminds you when the amount of insulin in the pump reaches this level", comment: "Description for low reservoir reminder")
        )
    }
    
    var body: some View {
        List {
            NavigationLink(destination: revervoirWarningView) {
                Text(LocalizedString("Low reservoir reminder", comment: "Text for low reservoir reminder"))
                    .foregroundColor(Color.primary)
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(LocalizedString("Cancel", comment: "Cancel button title"), action: {
                    self.dismiss()
                })
            }
        }
        .onChange(of: isPresented) { newValue in
            if newValue {
                viewModel.start()
            }
        }
    }
}

#Preview {
    DanaKitUserSettingsView(viewModel: DanaKitUserSettingsViewModel(nil))
}
