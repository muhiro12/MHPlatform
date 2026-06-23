#if canImport(SwiftUI)
import Foundation
import MHPreferences
import MHPreferencesUI
import SwiftUI
import Testing

enum AppStorageBridgeTestSupport {
    enum Constants {
        static let storageKeyPrefix = "tests.app-storage"

        static let boolDefaultValue = true
        static let intDefaultValue = 30
        static let intStoredValue = 12
        static let injectedBoolValue = true
        static let directDateReferenceInterval = 8.0
        static let directDateValue = Date(
            timeIntervalSinceReferenceDate: directDateReferenceInterval
        )
    }

    static func makeUserDefaults(suiteName: String) throws -> UserDefaults {
        let resolvedSuiteName = "AppStorageBridgeTests.\(suiteName)"
        let userDefaults = try #require(
            UserDefaults(suiteName: resolvedSuiteName)
        )
        userDefaults.removePersistentDomain(forName: resolvedSuiteName)
        return userDefaults
    }

    static func makeBoolKey(_ name: String) -> MHBoolPreferenceDescriptor {
        makeBoolKey(
            name,
            defaultSelection: .standard,
            default: false
        )
    }

    static func makeBoolKey(
        _ name: String,
        defaultSelection: MHUserDefaultsSelection
    ) -> MHBoolPreferenceDescriptor {
        makeBoolKey(
            name,
            defaultSelection: defaultSelection,
            default: false
        )
    }

    static func makeBoolKey(
        _ name: String,
        default defaultValue: Bool
    ) -> MHBoolPreferenceDescriptor {
        makeBoolKey(
            name,
            defaultSelection: .standard,
            default: defaultValue
        )
    }

    static func makeBoolKey(
        _ name: String,
        defaultSelection: MHUserDefaultsSelection,
        default defaultValue: Bool
    ) -> MHBoolPreferenceDescriptor {
        .init(
            storageKey: "\(Constants.storageKeyPrefix).\(name)",
            defaultSelection: defaultSelection,
            default: defaultValue
        )
    }

    static func makeIntKey(_ name: String) -> MHIntPreferenceDescriptor {
        makeIntKey(
            name,
            defaultSelection: .standard,
            default: .zero
        )
    }

    static func makeIntKey(
        _ name: String,
        default defaultValue: Int
    ) -> MHIntPreferenceDescriptor {
        makeIntKey(
            name,
            defaultSelection: .standard,
            default: defaultValue
        )
    }

    static func makeIntKey(
        _ name: String,
        defaultSelection: MHUserDefaultsSelection,
        default defaultValue: Int
    ) -> MHIntPreferenceDescriptor {
        .init(
            storageKey: "\(Constants.storageKeyPrefix).\(name)",
            defaultSelection: defaultSelection,
            default: defaultValue
        )
    }

    static func makeStringKey(_ name: String) -> MHStringPreferenceDescriptor {
        makeStringKey(
            name,
            defaultSelection: .standard
        )
    }

    static func makeStringKey(
        _ name: String,
        defaultSelection: MHUserDefaultsSelection
    ) -> MHStringPreferenceDescriptor {
        .init(
            storageKey: "\(Constants.storageKeyPrefix).\(name)",
            defaultSelection: defaultSelection
        )
    }

    static func makeDateKey(_ name: String) -> MHDatePreferenceDescriptor {
        makeDateKey(
            name,
            defaultSelection: .standard
        )
    }

    static func makeDateKey(
        _ name: String,
        defaultSelection: MHUserDefaultsSelection
    ) -> MHDatePreferenceDescriptor {
        .init(
            storageKey: "\(Constants.storageKeyPrefix).\(name)",
            defaultSelection: defaultSelection
        )
    }

    static func clearPersistentDomain(named suiteName: String) throws {
        let userDefaults = try #require(
            UserDefaults(suiteName: suiteName)
        )
        userDefaults.removePersistentDomain(forName: suiteName)
    }
}
#endif
