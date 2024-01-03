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
    
    public init(rawValue: RawValue) {
        self.lastStatusDate = rawValue["lastStatusDate"] as? Date ?? Date()
        self.deviceName = rawValue["deviceName"] as? String
        self.isConnected = rawValue["isConnected"] != nil
        self.reservoirLevel = rawValue["reservoirLevel"] as? Double ?? 0
        self.hwModel = rawValue["hwModel"] as? UInt8 ?? 0
        self.pumpProtocol = rawValue["pumpProtocol"] as? UInt8 ?? 0
        self.deviceIsRequestingPincode = rawValue["deviceIsRequestingPincode"] != nil
        self.isInFetchHistoryMode = rawValue["isInFetchHistoryMode"] != nil
        self.ignorePassword = rawValue["ignorePassword"] != nil
        self.devicePassword = rawValue["devicePassword"] as? UInt16 ?? 0
        self.isEasyMode = rawValue["isEasyMode"] != nil
        self.isUnitUD = rawValue["isUnitUD"] != nil
        self.bolusSpeed = rawValue["bolusSpeed"] as? BolusSpeed ?? .speed12
        self.isOnBoarded = rawValue["isOnBoarded"] as? Bool ?? false
        
        if let rawInsulinType = rawValue["insulinType"] as? InsulinType.RawValue {
            insulinType = InsulinType(rawValue: rawInsulinType)
        }
    }
    
    public var rawValue: RawValue {
        var value: [String : Any] = [:]
        
        value["lastStatusDate"] = self.lastStatusDate
        value["deviceName"] = self.deviceName
        value["bleIdentifier"] = self.bleIdentifier
        value["isConnected"] = self.isConnected
        value["reservoirLevel"] = self.reservoirLevel
        value["hwModel"] = self.hwModel
        value["pumpProtocol"] = self.pumpProtocol
        value["deviceIsRequestingPincode"] = self.deviceIsRequestingPincode
        value["isInFetchHistoryMode"] = self.isInFetchHistoryMode
        value["ignorePassword"] = self.ignorePassword
        value["devicePassword"] = self.devicePassword
        value["isEasyMode"] = self.isEasyMode
        value["isUnitUD"] = self.isUnitUD
        value["insulinType"] = self.insulinType?.rawValue
        value["bolusSpeed"] = self.bolusSpeed.rawValue
        value["isOnBoarded"] = self.isOnBoarded
        
        return value
    }
    
    /// The last moment this state has been updated (only for relavant values like isConnected or reservoirLevel)
    public var lastStatusDate: Date = Date()
    
    public var isOnBoarded = false {
        didSet {
            lastStatusDate = Date()
        }
    }
    
    /// The name of the device. Needed for en/de-crypting messages
    public var deviceName: String? = nil {
        didSet {
            lastStatusDate = Date()
        }
    }
    
    /// The bluetooth identifier. Used to reconnect to pump
    public var bleIdentifier: String? = nil {
        didSet {
            lastStatusDate = Date()
        }
    }
    
    /// Flag for checking if the device is still connected
    public var isConnected: Bool = false {
        didSet {
            lastStatusDate = Date()
        }
    }
    
    /// Current reservoir levels
    public var reservoirLevel: Double = 0  {
        didSet {
            lastStatusDate = Date()
        }
    }
    
    /// The hardware model of the pump. Dertermines the friendly device name
    public var hwModel: UInt8 = 0x00  {
        didSet {
            lastStatusDate = Date()
        }
    }
    
    /// Pump protocol
    public var pumpProtocol: UInt8 = 0x00  {
        didSet {
            lastStatusDate = Date()
        }
    }
    
    public var bolusSpeed: BolusSpeed = .speed12 {
        didSet {
            lastStatusDate = Date()
        }
    }
    
    public var insulinType: InsulinType? = nil
    
    /// When this bool is set to true, the UI should ask the user for a pincode
    /// and the code should call BluetoothManager.finishV3Pairing. Only applicable to DanaRS v3
    /// See: https://androidaps.readthedocs.io/en/latest/Configuration/DanaRS-Insulin-Pump.html#pairing-pump
    public var deviceIsRequestingPincode: Bool = false;
    
    /// When this bool is set to true, the UI should prompt the user to let them unbound the device and try it again.
    /// This is only an issue with Dana-i pumps
    public var deviceSendInvalidBLE5Keys = false
    
    /// The pump should be in history fetch mode, before requesting history data
    public var isInFetchHistoryMode: Bool = false
    
    public var ignorePassword: Bool = false
    public var devicePassword: UInt16 = 0
    
    // Use of these 2 bools are unknown...
    public var isEasyMode: Bool = false
    public var isUnitUD: Bool = false
    
    mutating func resetState() {
        self.ignorePassword = false
        self.devicePassword = 0
        self.isEasyMode = false
        self.isUnitUD = false
        self.deviceSendInvalidBLE5Keys = false
        self.isInFetchHistoryMode = false
        self.deviceIsRequestingPincode = false
    }
    
    func getFriendlyDeviceName() -> String {
        switch (self.hwModel) {
            case 0x01:
                return "DanaR Korean";

            case 0x03:
            switch (self.pumpProtocol) {
                case 0x00:
                  return "DanaR old";
                case 0x02:
                  return "DanaR v2";
                default:
                  return "DanaR"; // 0x01 and 0x03 known
              }

            case 0x05:
                return self.pumpProtocol < 10 ? "DanaRS" : "DanaRS v3";

            case 0x06:
                return "DanaRS Korean";

            case 0x07:
                return "Dana-i (BLE4.2)";

            case 0x09:
                return "Dana-i (BLE5)";
            case 0x0a:
                return "Dana-i (BLE5, Korean)";
            default:
                return "Unknown Dana pump";
          }
    }
}

extension DanaKitPumpManagerState: CustomDebugStringConvertible {
    public var debugDescription: String {
        return [
            "## DanaKitPumpManagerState",
            "* isOnboarded: \(isOnBoarded)",
            "* isConnected: \(isConnected)",
            "* deviceName: \(String(describing: deviceName))",
            "* bleIdentifier: \(String(describing: bleIdentifier))",
            "* friendlyDeviceName: \(getFriendlyDeviceName())",
            "* insulinType: \(String(describing: insulinType))",
            "* reservoirLevel: \(reservoirLevel)",
            "* hwModel: \(hwModel)",
            "* pumpProtocol: \(pumpProtocol)",
            "* isInFetchHistoryMode: \(isInFetchHistoryMode)",
            "* deviceIsRequestingPincode: \(deviceIsRequestingPincode)",
            "* deviceSendInvalidBLE5Keys: \(deviceSendInvalidBLE5Keys)",
            "* ignorePassword: \(ignorePassword)",
            "* isEasyMode: \(isEasyMode)",
            "* isUnitUD: \(isUnitUD)"
        ].joined(separator: "\n")
    }
}
