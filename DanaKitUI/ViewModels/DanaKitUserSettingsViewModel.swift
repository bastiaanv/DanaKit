//
//  DanaKitUserSettingsViewModel.swift
//  DanaKit
//
//  Created by Bastiaan Verhaar on 29/01/2024.
//  Copyright © 2024 Randall Knutson. All rights reserved.
//

import Foundation
import LoopKit

class DanaKitUserSettingsViewModel : ObservableObject {
    @Published var initialLoading: Bool = true
    
    var lowReservoirLevel: Int {
        Int(model?.lowReservoirRate ?? 0)
    }
    
    private var model: PacketGeneralGetUserOption?
    private let pumpManager: DanaKitPumpManager?
    
    init(_ pumpManager: DanaKitPumpManager?) {
        self.pumpManager = pumpManager
    }
    
    func start() {
        self.pumpManager?.getUserSettings(completion: parseResult)
    }
    
    private func parseResult(_ result: PacketGeneralGetUserOption?) {
        guard let result = result else {
            return
        }
        
        self.initialLoading = false
        self.model = result
    }
}
