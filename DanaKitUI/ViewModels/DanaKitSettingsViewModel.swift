//
//  DanaKitSettingsViewModel.swift
//  DanaKit
//
//  Created by Bastiaan Verhaar on 03/01/2024.
//  Copyright © 2024 Randall Knutson. All rights reserved.
//

import SwiftUI
import os.log
import LoopKit

class DanaKitSettingsViewModel : ObservableObject {
    @Published var showingDeleteConfirmation = false
    @Published var basalButtonText: String = ""
    
    private(set) var insulineType: InsulinType
    private var pumpManager: DanaKitPumpManager?
    private var didFinish: (() -> Void)?
    
    public var pumpModel: String {
        self.pumpManager?.state.getFriendlyDeviceName() ?? ""
    }
    
    public var isSuspended: Bool {
        self.pumpManager?.state.isPumpSuspended ?? true
    }
    
    public var basalRate: Double? {
        self.pumpManager?.currentBaseBasalRate
    }
    
    let basalRateFormatter: NumberFormatter = {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        numberFormatter.minimumFractionDigits = 1
        numberFormatter.minimumIntegerDigits = 1
        return numberFormatter
    }()
    
    public init(_ pumpManager: DanaKitPumpManager?, _ didFinish: (() -> Void)?) {
        self.pumpManager = pumpManager
        self.didFinish = didFinish
        
        self.insulineType = self.pumpManager?.state.insulinType ?? .novolog
        
        self.basalButtonText = self.updateBasalButtonText()
    }
    
    func stopUsingDana() {
        self.pumpManager?.notifyDelegateOfDeactivation {
            DispatchQueue.main.async {
                self.didFinish?()
            }
        }
    }
    
    func didChangeInsulinType(_ newType: InsulinType?) {
        guard let type = newType else {
            return
        }
        
        print("Update insulin type: " + (newType?.brandName ?? "EMPTY"))
        self.pumpManager?.state.insulinType = type
        self.insulineType = type
    }
    
    func suspendResumeButtonPressed() {
        guard self.pumpManager?.state.isConnected ?? false else {
            return
        }
        
        if self.pumpManager?.state.isPumpSuspended ?? false {
            self.pumpManager?.resumeDelivery(completion: { error in
                guard error == nil else {
                    return
                }
                
                self.basalButtonText = self.updateBasalButtonText()
            })
            
            return
        }
        
        if self.pumpManager?.state.isTempBasalInProgress ?? false {
            // Stop temp basal
            self.pumpManager?.enactTempBasal(unitsPerHour: 0, for: 0, completion: { error in
                guard error == nil else {
                    return
                }
                
                self.basalButtonText = self.updateBasalButtonText()
            })
            
            return
        }
        
        self.pumpManager?.suspendDelivery(completion: { error in
            guard error == nil else {
                return
            }
            
            self.basalButtonText = self.updateBasalButtonText()
        })
    }
    
    private func updateBasalButtonText() -> String {
        if self.pumpManager?.state.isPumpSuspended ?? false {
            return LocalizedString("Resume delivery", comment: "Dana settings resume delivery")
        }
        
        if self.pumpManager?.state.isTempBasalInProgress ?? false {
            return LocalizedString("Stop temp basal", comment: "Dana settings stop temp basal")
        }
        
        return LocalizedString("Suspend delivery", comment: "Dana settings suspend delivery")
    }
}
