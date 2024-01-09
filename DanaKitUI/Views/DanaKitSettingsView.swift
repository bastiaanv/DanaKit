//
//  DanaKitSettingsView.swift
//  DanaKit
//
//  Created by Bastiaan Verhaar on 03/01/2024.
//  Copyright © 2024 Randall Knutson. All rights reserved.
//

import SwiftUI
import LoopKit
import LoopKitUI

struct DanaKitSettingsView: View {
    @Environment(\.guidanceColors) var guidanceColors
    
    @ObservedObject var viewModel: DanaKitSettingsViewModel
    
    var imageName: String
    
    var removePumpManagerActionSheet: ActionSheet {
        ActionSheet(title: Text(LocalizedString("Remove Pump", comment: "Title for Dana-i/RS PumpManager deletion action sheet.")),
                    message: Text(LocalizedString("Are you sure you want to stop using Dana-i/RS?", comment: "Message for Dana-i/RS PumpManager deletion action sheet")),
                    buttons: [
                        .destructive(Text(LocalizedString("Delete pump", comment: "Button text to confirm Dana-i/RS PumpManager deletion"))) {
                            viewModel.stopUsingDana()
                        },
                        .cancel()
        ])
    }
    
    var body: some View {
        Image(uiImage: UIImage(named: imageName, in: Bundle(for: DanaKitHUDProvider.self), compatibleWith: nil)!)
            .resizable()
            .scaledToFit()
            .frame(height: 200)
        Button(action: {
            viewModel.showingDeleteConfirmation = true
        }) {
            Text(LocalizedString("Switch to other insulin delivery device", comment: "Label for PumpManager deletion button"))
                .foregroundColor(guidanceColors.critical)
        }
        .actionSheet(isPresented: $viewModel.showingDeleteConfirmation) {
            removePumpManagerActionSheet
        }
    }
}

#Preview {
    DanaKitSettingsView(viewModel: DanaKitSettingsViewModel(nil, nil), imageName: "danai")
}
