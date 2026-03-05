#if canImport(SwiftUI)
import Foundation
import SwiftUI

public extension AppStorage {
    /// Creates a boolean app-storage binding using a typed preference key.
    init(
        _ key: MHBoolPreferenceKey,
        store: UserDefaults = .standard
    ) where Value == Bool {
        self.init(
            wrappedValue: key.defaultValue,
            key.storageKey,
            store: store
        )
    }

    /// Creates an integer app-storage binding using a typed preference key.
    init(
        _ key: MHIntPreferenceKey,
        store: UserDefaults = .standard
    ) where Value == Int {
        self.init(
            wrappedValue: key.defaultValue,
            key.storageKey,
            store: store
        )
    }

    /// Creates an optional-string app-storage binding using a typed preference key.
    init(
        _ key: MHStringPreferenceKey,
        store: UserDefaults = .standard
    ) where Value == String? {
        self.init(
            key.storageKey,
            store: store
        )
    }
}
#endif
