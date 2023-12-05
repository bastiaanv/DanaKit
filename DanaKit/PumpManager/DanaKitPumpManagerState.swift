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
}
