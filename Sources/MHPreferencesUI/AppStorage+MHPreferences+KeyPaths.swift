#if canImport(SwiftUI)
import Foundation
import MHPreferences
import SwiftUI

public extension AppStorage {
    /// Creates a boolean app-storage binding using a descriptor namespace.
    init(
        _ keyPath: KeyPath<MHPreferenceDescriptors, MHBoolPreferenceDescriptor>
    ) where Value == Bool {
        self.init(
            MHPreferenceDescriptors()[keyPath: keyPath]
        )
    }

    /// Creates a boolean app-storage binding using a descriptor namespace.
    init(
        _ keyPath: KeyPath<MHPreferenceDescriptors, MHBoolPreferenceDescriptor>,
        store: UserDefaults
    ) where Value == Bool {
        self.init(
            MHPreferenceDescriptors()[keyPath: keyPath],
            store: store
        )
    }

    /// Creates an integer app-storage binding using a descriptor namespace.
    init(
        _ keyPath: KeyPath<MHPreferenceDescriptors, MHIntPreferenceDescriptor>
    ) where Value == Int {
        self.init(
            MHPreferenceDescriptors()[keyPath: keyPath]
        )
    }

    /// Creates an integer app-storage binding using a descriptor namespace.
    init(
        _ keyPath: KeyPath<MHPreferenceDescriptors, MHIntPreferenceDescriptor>,
        store: UserDefaults
    ) where Value == Int {
        self.init(
            MHPreferenceDescriptors()[keyPath: keyPath],
            store: store
        )
    }

    /// Creates an optional-string app-storage binding using a descriptor namespace.
    init(
        _ keyPath: KeyPath<MHPreferenceDescriptors, MHStringPreferenceDescriptor>
    ) where Value == String? {
        self.init(
            MHPreferenceDescriptors()[keyPath: keyPath]
        )
    }

    /// Creates an optional-string app-storage binding using a descriptor namespace.
    init(
        _ keyPath: KeyPath<MHPreferenceDescriptors, MHStringPreferenceDescriptor>,
        store: UserDefaults
    ) where Value == String? {
        self.init(
            MHPreferenceDescriptors()[keyPath: keyPath],
            store: store
        )
    }

    /// Creates a string app-storage binding using a descriptor namespace.
    init(
        _ keyPath: KeyPath<MHPreferenceDescriptors, MHStringPreferenceDescriptor>,
        default defaultValue: String
    ) where Value == String {
        self.init(
            MHPreferenceDescriptors()[keyPath: keyPath],
            default: defaultValue
        )
    }

    /// Creates a string app-storage binding using a descriptor namespace.
    init(
        _ keyPath: KeyPath<MHPreferenceDescriptors, MHStringPreferenceDescriptor>,
        default defaultValue: String,
        store: UserDefaults
    ) where Value == String {
        self.init(
            MHPreferenceDescriptors()[keyPath: keyPath],
            default: defaultValue,
            store: store
        )
    }

    /// Creates a raw-string app-storage binding using a descriptor namespace.
    init(
        _ keyPath: KeyPath<MHPreferenceDescriptors, MHStringPreferenceDescriptor>,
        default defaultValue: Value
    ) where Value: RawRepresentable, Value.RawValue == String {
        self.init(
            MHPreferenceDescriptors()[keyPath: keyPath],
            default: defaultValue
        )
    }

    /// Creates a raw-string app-storage binding using a descriptor namespace.
    init(
        _ keyPath: KeyPath<MHPreferenceDescriptors, MHStringPreferenceDescriptor>,
        default defaultValue: Value,
        store: UserDefaults
    ) where Value: RawRepresentable, Value.RawValue == String {
        self.init(
            MHPreferenceDescriptors()[keyPath: keyPath],
            default: defaultValue,
            store: store
        )
    }

    /// Creates an optional-date app-storage binding using a descriptor namespace.
    init(
        _ keyPath: KeyPath<MHPreferenceDescriptors, MHDatePreferenceDescriptor>
    ) where Value == Date? {
        self.init(
            MHPreferenceDescriptors()[keyPath: keyPath]
        )
    }

    /// Creates an optional-date app-storage binding using a descriptor namespace.
    init(
        _ keyPath: KeyPath<MHPreferenceDescriptors, MHDatePreferenceDescriptor>,
        store: UserDefaults
    ) where Value == Date? {
        self.init(
            MHPreferenceDescriptors()[keyPath: keyPath],
            store: store
        )
    }

    /// Creates a date app-storage binding using a descriptor namespace.
    init(
        _ keyPath: KeyPath<MHPreferenceDescriptors, MHDatePreferenceDescriptor>,
        default defaultValue: Date
    ) where Value == Date {
        self.init(
            MHPreferenceDescriptors()[keyPath: keyPath],
            default: defaultValue
        )
    }

    /// Creates a date app-storage binding using a descriptor namespace.
    init(
        _ keyPath: KeyPath<MHPreferenceDescriptors, MHDatePreferenceDescriptor>,
        default defaultValue: Date,
        store: UserDefaults
    ) where Value == Date {
        self.init(
            MHPreferenceDescriptors()[keyPath: keyPath],
            default: defaultValue,
            store: store
        )
    }
}
#endif
