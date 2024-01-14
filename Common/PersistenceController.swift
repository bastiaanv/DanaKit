//
//  PersistenceController.swift
//  DanaKit
//
//  Created by Bastiaan Verhaar on 14/01/2024.
//  Copyright © 2024 Randall Knutson. All rights reserved.
//

import LoopKit

extension Bundle {
    var appGroupSuiteName: String {
        return object(forInfoDictionaryKey: "AppGroupIdentifier") as! String
    }
}

extension PersistenceController {
    public class func controllerInAppGroupDirectory(isReadOnly: Bool = false) -> PersistenceController {
        let appGroup = Bundle.main.appGroupSuiteName
        guard let directoryURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) else {
            assertionFailure("Could not get a container directory URL. Please ensure App Groups are set up correctly in entitlements.")
            return self.init(directoryURL: URL(fileURLWithPath: "/"))
        }
        
        return self.init(directoryURL: directoryURL.appendingPathComponent("com.loopkit.LoopKit", isDirectory: true), isReadOnly: isReadOnly)
    }
}
