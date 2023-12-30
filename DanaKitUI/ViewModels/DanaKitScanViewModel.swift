//
//  DanaKitScanViewModel.swift
//  DanaKit
//
//  Created by Bastiaan Verhaar on 28/12/2023.
//  Copyright © 2023 Randall Knutson. All rights reserved.
//

import SwiftUI
import os.log
import LoopKit

struct ScanResultItem: Identifiable {
    let id = UUID()
    var device: DanaPumpScan
}

class DanaKitScanViewModel : ObservableObject {
    @Published var scannedDevices: [ScanResultItem] = []
    @Published var isConnecting = false
     
    private let log = OSLog(category: "ScanView")
    private var pumpManager: DanaKitPumpManager?
    private var nextStep: () -> Void
    
    init(_ pumpManager: DanaKitPumpManager? = nil, nextStep: @escaping () -> Void) {
        self.pumpManager = pumpManager
        self.nextStep = nextStep
        
        self.pumpManager?.addScanDeviceObserver(self, queue: .main)
        self.pumpManager?.addStateObserver(self, queue: .main)
        
        self.pumpManager?.startScan()
    }
    
    func connect(_ item: ScanResultItem) {
        self.stopScan()
        self.pumpManager?.connect(item.device.peripheral)
        self.isConnecting = true
    }
    
    func stopScan() {
        self.pumpManager?.stopScan()
    }
}

extension DanaKitScanViewModel: StateObserver {
    func deviceScanDidUpdate(_ device: DanaPumpScan) {
        log.debug("Received event")
        
        self.scannedDevices.append(ScanResultItem(device: device))
    }
    
    func stateDidUpdate(_ state: DanaKitPumpManagerState, _ oldState: DanaKitPumpManagerState) {
        if (state.isConnected && state.deviceName != nil) {
            self.isConnecting = false
            self.nextStep()
        }
    }
}
