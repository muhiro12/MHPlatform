#if canImport(SwiftUI)
import Foundation
import SwiftUI

public extension AppStorage {
    /// Creates a boolean app-storage binding using a typed preference descriptor.
    init(
        _ descriptor: MHBoolPreferenceDescriptor
    ) where Value == Bool {
        self.init(
            descriptor,
            store: descriptor.defaultSelection.resolveUserDefaults()
        )
    }

    /// Creates a boolean app-storage binding using a typed preference descriptor.
    init(
        _ descriptor: MHBoolPreferenceDescriptor,
        store: UserDefaults
    ) where Value == Bool {
        self.init(
            wrappedValue: descriptor.defaultValue,
            descriptor.storageKey,
            store: store
        )
    }

    /// Creates an integer app-storage binding using a typed preference descriptor.
    init(
        _ descriptor: MHIntPreferenceDescriptor
    ) where Value == Int {
        self.init(
            descriptor,
            store: descriptor.defaultSelection.resolveUserDefaults()
        )
    }

    /// Creates an integer app-storage binding using a typed preference descriptor.
    init(
        _ descriptor: MHIntPreferenceDescriptor,
        store: UserDefaults
    ) where Value == Int {
        self.init(
            wrappedValue: descriptor.defaultValue,
            descriptor.storageKey,
            store: store
        )
    }

    /// Creates an optional-string app-storage binding using a typed preference descriptor.
    init(
        _ descriptor: MHStringPreferenceDescriptor
    ) where Value == String? {
        self.init(
            descriptor,
            store: descriptor.defaultSelection.resolveUserDefaults()
        )
    }

    /// Creates an optional-string app-storage binding using a typed preference descriptor.
    init(
        _ descriptor: MHStringPreferenceDescriptor,
        store: UserDefaults
    ) where Value == String? {
        self.init(
            descriptor.storageKey,
            store: store
        )
    }

    /// Creates a string app-storage binding using a typed preference descriptor.
    init(
        _ descriptor: MHStringPreferenceDescriptor,
        default defaultValue: String
    ) where Value == String {
        self.init(
            descriptor,
            default: defaultValue,
            store: descriptor.defaultSelection.resolveUserDefaults()
        )
    }

    /// Creates a string app-storage binding using a typed preference descriptor.
    init(
        _ descriptor: MHStringPreferenceDescriptor,
        default defaultValue: String,
        store: UserDefaults
    ) where Value == String {
        self.init(
            wrappedValue: defaultValue,
            descriptor.storageKey,
            store: store
        )
    }

    /// Creates a raw-string app-storage binding using a typed preference descriptor.
    init(
        _ descriptor: MHStringPreferenceDescriptor,
        default defaultValue: Value
    ) where Value: RawRepresentable, Value.RawValue == String {
        self.init(
            descriptor,
            default: defaultValue,
            store: descriptor.defaultSelection.resolveUserDefaults()
        )
    }

    /// Creates a raw-string app-storage binding using a typed preference descriptor.
    init(
        _ descriptor: MHStringPreferenceDescriptor,
        default defaultValue: Value,
        store: UserDefaults
    ) where Value: RawRepresentable, Value.RawValue == String {
        self.init(
            wrappedValue: defaultValue,
            descriptor.storageKey,
            store: store
        )
    }

    /// Creates a boolean app-storage binding using a representable typed descriptor.
    init(
        _ descriptor: some MHBoolPrefDescriptorRepresentable
    ) where Value == Bool {
        self.init(
            descriptor.preferenceDescriptor
        )
    }

    /// Creates a boolean app-storage binding using a representable typed descriptor.
    init(
        _ descriptor: some MHBoolPrefDescriptorRepresentable,
        store: UserDefaults
    ) where Value == Bool {
        self.init(
            descriptor.preferenceDescriptor,
            store: store
        )
    }

    /// Creates an integer app-storage binding using a representable typed descriptor.
    init(
        _ descriptor: some MHIntPrefDescriptorRepresentable
    ) where Value == Int {
        self.init(
            descriptor.preferenceDescriptor(default: .zero)
        )
    }

    /// Creates an integer app-storage binding using a representable typed descriptor.
    init(
        _ descriptor: some MHIntPrefDescriptorRepresentable,
        store: UserDefaults
    ) where Value == Int {
        self.init(
            descriptor.preferenceDescriptor(default: .zero),
            store: store
        )
    }

    /// Creates an optional-string app-storage binding using a representable typed descriptor.
    init(
        _ descriptor: some MHStringPrefDescriptorRepresentable
    ) where Value == String? {
        self.init(
            descriptor.preferenceDescriptor
        )
    }

    /// Creates an optional-string app-storage binding using a representable typed descriptor.
    init(
        _ descriptor: some MHStringPrefDescriptorRepresentable,
        store: UserDefaults
    ) where Value == String? {
        self.init(
            descriptor.preferenceDescriptor,
            store: store
        )
    }

    /// Creates a string app-storage binding using a representable typed descriptor.
    init(
        _ descriptor: some MHStringPrefDescriptorRepresentable
    ) where Value == String {
        self.init(
            descriptor.preferenceDescriptor,
            default: ""
        )
    }

    /// Creates a string app-storage binding using a representable typed descriptor.
    init(
        _ descriptor: some MHStringPrefDescriptorRepresentable,
        store: UserDefaults
    ) where Value == String {
        self.init(
            wrappedValue: "",
            descriptor.preferenceDescriptor.storageKey,
            store: store
        )
    }

    /// Creates a string app-storage binding using a representable typed descriptor and an explicit default.
    init(
        _ descriptor: some MHStringPrefDescriptorRepresentable,
        default defaultValue: String
    ) where Value == String {
        self.init(
            descriptor.preferenceDescriptor,
            default: defaultValue,
            store: descriptor.preferenceDescriptor.defaultSelection.resolveUserDefaults()
        )
    }

    /// Creates a string app-storage binding using a representable typed descriptor and an explicit default.
    init(
        _ descriptor: some MHStringPrefDescriptorRepresentable,
        default defaultValue: String,
        store: UserDefaults
    ) where Value == String {
        self.init(
            wrappedValue: defaultValue,
            descriptor.preferenceDescriptor.storageKey,
            store: store
        )
    }

    /// Creates a raw-string app-storage binding using a representable typed descriptor.
    init(
        _ descriptor: some MHStringPrefDescriptorRepresentable,
        default defaultValue: Value
    ) where Value: RawRepresentable, Value.RawValue == String {
        self.init(
            descriptor.preferenceDescriptor,
            default: defaultValue,
            store: descriptor.preferenceDescriptor.defaultSelection.resolveUserDefaults()
        )
    }

    /// Creates a raw-string app-storage binding using a representable typed descriptor.
    init(
        _ descriptor: some MHStringPrefDescriptorRepresentable,
        default defaultValue: Value,
        store: UserDefaults
    ) where Value: RawRepresentable, Value.RawValue == String {
        self.init(
            wrappedValue: defaultValue,
            descriptor.preferenceDescriptor.storageKey,
            store: store
        )
    }
}
#endif
