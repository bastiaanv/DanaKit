//
//  DanaKitSettingsPumpSpeed.swift
//  DanaKit
//
//  Created by Bastiaan Verhaar on 17/01/2024.
//  Copyright © 2024 Randall Knutson. All rights reserved.
//

import SwiftUI
import LoopKitUI

struct DanaKitSettingsPumpSpeed: View {
    let speedsAllowed = BolusSpeed.all()
    @Binding var value: Int
    
    private var selectedValue: Binding<Int> {
        Binding(
            get: { value },
            set: { newValue in
                value = newValue
                didChange?(BolusSpeed.init(rawValue: UInt8(newValue))!)
            }
        )
    }
    
    var didChange: ((BolusSpeed) -> Void)?
    
    var body: some View {
        VStack(alignment: .leading) {
            title
            content
        }
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var content: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text(LocalizedString("The Dana pumps support different delivery speeds. You can set it up here", comment: "Dana delivery speed body")).fixedSize(horizontal: false, vertical: true)
            Divider()
            ResizeablePicker(selection: selectedValue,
                                     data: self.speedsAllowed,
                                     formatter: { BolusSpeed.init(rawValue: UInt8($0))!.format() })
        }
        .padding(.vertical, 8)
        
    }
    
    @ViewBuilder
    private var title: some View {
        Text(LocalizedString("Delivery speed", comment: "Title for delivery speed"))
            .font(.title)
            .bold()
    }
}

#Preview {
    DanaKitSettingsPumpSpeed(value: .constant(0))
}
