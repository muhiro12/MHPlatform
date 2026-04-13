#if canImport(SwiftUI)
import Foundation
import MHPreferences
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

    static func makeBoolKey(
        _ name: String,
        defaultSelection: MHUserDefaultsSelection = .standard,
        default defaultValue: Bool = false
    ) -> MHBoolPreferenceDescriptor {
        .init(
            storageKey: "\(Constants.storageKeyPrefix).\(name)",
            defaultSelection: defaultSelection,
            default: defaultValue
        )
    }

    static func makeIntKey(
        _ name: String,
        defaultSelection: MHUserDefaultsSelection = .standard,
        default defaultValue: Int = .zero
    ) -> MHIntPreferenceDescriptor {
        .init(
            storageKey: "\(Constants.storageKeyPrefix).\(name)",
            defaultSelection: defaultSelection,
            default: defaultValue
        )
    }

    static func makeStringKey(
        _ name: String,
        defaultSelection: MHUserDefaultsSelection = .standard
    ) -> MHStringPreferenceDescriptor {
        .init(
            storageKey: "\(Constants.storageKeyPrefix).\(name)",
            defaultSelection: defaultSelection
        )
    }

    static func makeDateKey(
        _ name: String,
        defaultSelection: MHUserDefaultsSelection = .standard
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
