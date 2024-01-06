//
//  DanaKitPumpSpeed.swift
//  DanaKit
//
//  Created by Bastiaan Verhaar on 06/01/2024.
//  Copyright © 2024 Randall Knutson. All rights reserved.
//

import SwiftUI
import LoopKitUI

struct DanaKitPumpSpeed: View {
    @Environment(\.dismissAction) private var dismiss
    
    let speedsAllowed = BolusSpeed.all()
    @State var speedDefault = Int(BolusSpeed.speed12.rawValue)
    
    var next: ((BolusSpeed) -> Void)?
    
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
                    self.dismiss()
                })
            }
        }
    }
    
    @ViewBuilder
    private var content: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text(LocalizedString("The Dana pumps support different delivery speeds. You can set it up here, but also in the settings menu", comment: "Dana delivery speed body")).fixedSize(horizontal: false, vertical: true)
            Divider()
            ResizeablePicker(selection: $speedDefault,
                                     data: self.speedsAllowed,
                                     formatter: { formatter($0) })
            Spacer()
            VStack {
                Button(action: {
                    guard let speed = BolusSpeed(rawValue: UInt8($speedDefault.wrappedValue)) else {
                        return
                    }
                    
                    next?(speed)
                }) {
                    Text(LocalizedString("Continue", comment: "Text for continue button"))
                        .actionButtonStyle(.primary)
                }
            }
            .padding()
        }
        .padding(.vertical, 8)
        
    }
    
    @ViewBuilder
    private var title: some View {
        Text(LocalizedString("Delivery speed", comment: "Title for delivery speed"))
            .font(.title)
            .bold()
    }
    
    func formatter(_ speedOrdinal: Int) -> String {
        guard let speed = BolusSpeed(rawValue: UInt8(speedOrdinal)) else {
            return ""
        }
        
        switch(speed) {
        case .speed12:
            return LocalizedString("12 U/min", comment: "Dana bolus speed 12u per min")
        case .speed30:
            return LocalizedString("30 U/min", comment: "Dana bolus speed 30u per min")
        case .speed60:
            return LocalizedString("60 U/min", comment: "Dana bolus speed 60u per min")
        }
    }
}

#Preview {
    DanaKitPumpSpeed()
}
