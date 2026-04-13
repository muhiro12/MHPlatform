#if canImport(SwiftUI)
import Foundation
import SwiftUI

public extension AppStorage {
    /// Creates a boolean app-storage binding using a key namespace.
    init(
        _ keyPath: KeyPath<MHPreferenceKeys, MHBoolPreferenceDescriptor>
    ) where Value == Bool {
        self.init(
            MHPreferenceKeys()[keyPath: keyPath]
        )
    }

    /// Creates a boolean app-storage binding using a key namespace.
    init(
        _ keyPath: KeyPath<MHPreferenceKeys, MHBoolPreferenceDescriptor>,
        store: UserDefaults
    ) where Value == Bool {
        self.init(
            MHPreferenceKeys()[keyPath: keyPath],
            store: store
        )
    }

    /// Creates an integer app-storage binding using a key namespace.
    init(
        _ keyPath: KeyPath<MHPreferenceKeys, MHIntPreferenceDescriptor>
    ) where Value == Int {
        self.init(
            MHPreferenceKeys()[keyPath: keyPath]
        )
    }

    /// Creates an integer app-storage binding using a key namespace.
    init(
        _ keyPath: KeyPath<MHPreferenceKeys, MHIntPreferenceDescriptor>,
        store: UserDefaults
    ) where Value == Int {
        self.init(
            MHPreferenceKeys()[keyPath: keyPath],
            store: store
        )
    }

    /// Creates an optional-string app-storage binding using a key namespace.
    init(
        _ keyPath: KeyPath<MHPreferenceKeys, MHStringPreferenceDescriptor>
    ) where Value == String? {
        self.init(
            MHPreferenceKeys()[keyPath: keyPath]
        )
    }

    /// Creates an optional-string app-storage binding using a key namespace.
    init(
        _ keyPath: KeyPath<MHPreferenceKeys, MHStringPreferenceDescriptor>,
        store: UserDefaults
    ) where Value == String? {
        self.init(
            MHPreferenceKeys()[keyPath: keyPath],
            store: store
        )
    }

    /// Creates a string app-storage binding using a key namespace.
    init(
        _ keyPath: KeyPath<MHPreferenceKeys, MHStringPreferenceDescriptor>,
        default defaultValue: String
    ) where Value == String {
        self.init(
            MHPreferenceKeys()[keyPath: keyPath],
            default: defaultValue
        )
    }

    /// Creates a string app-storage binding using a key namespace.
    init(
        _ keyPath: KeyPath<MHPreferenceKeys, MHStringPreferenceDescriptor>,
        default defaultValue: String,
        store: UserDefaults
    ) where Value == String {
        self.init(
            MHPreferenceKeys()[keyPath: keyPath],
            default: defaultValue,
            store: store
        )
    }

    /// Creates a raw-string app-storage binding using a key namespace.
    init(
        _ keyPath: KeyPath<MHPreferenceKeys, MHStringPreferenceDescriptor>,
        default defaultValue: Value
    ) where Value: RawRepresentable, Value.RawValue == String {
        self.init(
            MHPreferenceKeys()[keyPath: keyPath],
            default: defaultValue
        )
    }

    /// Creates a raw-string app-storage binding using a key namespace.
    init(
        _ keyPath: KeyPath<MHPreferenceKeys, MHStringPreferenceDescriptor>,
        default defaultValue: Value,
        store: UserDefaults
    ) where Value: RawRepresentable, Value.RawValue == String {
        self.init(
            MHPreferenceKeys()[keyPath: keyPath],
            default: defaultValue,
            store: store
        )
    }

    /// Creates an optional-date app-storage binding using a key namespace.
    init(
        _ keyPath: KeyPath<MHPreferenceKeys, MHDatePreferenceDescriptor>
    ) where Value == Date? {
        self.init(
            MHPreferenceKeys()[keyPath: keyPath]
        )
    }

    /// Creates an optional-date app-storage binding using a key namespace.
    init(
        _ keyPath: KeyPath<MHPreferenceKeys, MHDatePreferenceDescriptor>,
        store: UserDefaults
    ) where Value == Date? {
        self.init(
            MHPreferenceKeys()[keyPath: keyPath],
            store: store
        )
    }

    /// Creates a date app-storage binding using a key namespace.
    init(
        _ keyPath: KeyPath<MHPreferenceKeys, MHDatePreferenceDescriptor>,
        default defaultValue: Date
    ) where Value == Date {
        self.init(
            MHPreferenceKeys()[keyPath: keyPath],
            default: defaultValue
        )
    }

    /// Creates a date app-storage binding using a key namespace.
    init(
        _ keyPath: KeyPath<MHPreferenceKeys, MHDatePreferenceDescriptor>,
        default defaultValue: Date,
        store: UserDefaults
    ) where Value == Date {
        self.init(
            MHPreferenceKeys()[keyPath: keyPath],
            default: defaultValue,
            store: store
        )
    }
}
#endif
