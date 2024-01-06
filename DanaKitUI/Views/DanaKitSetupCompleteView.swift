//
//  DanaKitSetupCompleteView.swift
//  DanaKit
//
//  Created by Bastiaan Verhaar on 06/01/2024.
//  Copyright © 2024 Randall Knutson. All rights reserved.
//

import SwiftUI
import LoopKitUI

struct DanaKitSetupCompleteView: View {
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    static let regularScreenImageHeight: CGFloat = 150
    
    var finish: (() -> Void)?
    var friendlyPumpModelName: String
    
    var body: some View {
        GuidePage(content: {
            VStack(alignment: .leading) {
                title
            }
        }) {
            Button(action: {
                finish?()
            }) {
                Text(LocalizedString("Finish", comment: "Text for finish button"))
                    .actionButtonStyle(.primary)
            }
            .padding()
            .background(Color(UIColor.systemBackground))
            .zIndex(1)
        }
        .animation(.default)
        .navigationBarTitle("Setup Complete", displayMode: .automatic)
    }
    
    @ViewBuilder
    private var title: some View {
        Text(LocalizedString("Your ", comment: "Dana setup complete p1") + friendlyPumpModelName + LocalizedString(" is ready to be used!", comment: "Dana setup complete p2"))
    } 
}

#Preview {
    DanaKitSetupCompleteView(finish: {}, friendlyPumpModelName: "Dana-i")
}
