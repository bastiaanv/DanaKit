//
//  DanaKitPumpManagerState.swift
//  DanaKit
//
//  Based on OmniKit/PumpManager/OmnipodPumpManagerState.swift
//  Created by Pete Schwamb on 8/4/18.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

import LoopKit


public struct DanaKitPumpManagerState: RawRepresentable, Equatable {
    public typealias RawValue = PumpManager.RawStateValue
    
    public init?(rawValue: RawValue) {
    }
    
    public var rawValue: RawValue {
        var value: [String : Any] = [:]
        return value
    }

    public var autoConnect: Bool = true
    
    public var deviceName: String? = nil
    public var deviceAddress: String? = nil
    public var isConnected: Bool = false
    
    public var hwModel: UInt8 = 0x00;
    public var pumpProtocol: UInt8 = 0x00;
    
    /// When this bool is set to true, the UI should ask the user for a pincode
    /// and the code should call BluetoothManager.finishV3Pairing. Only applicable to DanaRS v3
    /// See: https://androidaps.readthedocs.io/en/latest/Configuration/DanaRS-Insulin-Pump.html#pairing-pump
    public var deviceIsRequestingPincode: Bool = false;
    
    public var ignorePassword: Bool = false
    public var devicePassword: Uint16 = 0
    
    // Use of these 2 bools are unknown...
    public var isEasyMode: Bool = false
    public var isUnitUD: Bool = false
}
