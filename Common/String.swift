import SwiftUI

extension Text {
    init(_ key: LocalizedStringKey, comment: StaticString = "") {
        self.init(key, bundle: Bundle(for: DanaKitHUDProvider.self), comment: comment)
    }
}

extension String {
    init(localized key: String.LocalizationValue, comment: StaticString = "") {
        self.init(localized: key, bundle: Bundle(for: DanaKitHUDProvider.self), comment: comment)
    }
}
