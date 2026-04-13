import Foundation
import MHPreferences

enum MHPreferenceKeysTestSupport {
    struct DemoCodablePreferenceValue: Codable, Equatable, Sendable {
        let title: String
        let count: Int
    }

    static let storageKeyPrefix = "tests.preference-keys"
    static let boolSuiteName = "MHPreferencesTests.PreferenceKeys.bool"
    static let intSuiteName = "MHPreferencesTests.PreferenceKeys.int"
    static let stringSuiteName = "MHPreferencesTests.PreferenceKeys.string"
    static let dateSuiteName = "MHPreferencesTests.PreferenceKeys.date"
    static let codableSuiteName = "MHPreferencesTests.PreferenceKeys.codable"
    static let launchCountDefaultValue = 3
}

extension MHPreferenceKeys {
    var hasSeenOnboarding: MHBoolPreferenceDescriptor {
        .init(
            storageKey: "\(MHPreferenceKeysTestSupport.storageKeyPrefix).has-seen-onboarding",
            defaultSelection: .suite(MHPreferenceKeysTestSupport.boolSuiteName),
            default: true
        )
    }

    var launchCount: MHIntPreferenceDescriptor {
        .init(
            storageKey: "\(MHPreferenceKeysTestSupport.storageKeyPrefix).launch-count",
            defaultSelection: .suite(MHPreferenceKeysTestSupport.intSuiteName),
            default: MHPreferenceKeysTestSupport.launchCountDefaultValue
        )
    }

    var displayName: MHStringPreferenceDescriptor {
        .init(
            storageKey: "\(MHPreferenceKeysTestSupport.storageKeyPrefix).display-name",
            defaultSelection: .suite(MHPreferenceKeysTestSupport.stringSuiteName)
        )
    }

    var lastSeenAt: MHDatePreferenceDescriptor {
        .init(
            storageKey: "\(MHPreferenceKeysTestSupport.storageKeyPrefix).last-seen-at",
            defaultSelection: .suite(MHPreferenceKeysTestSupport.dateSuiteName)
        )
    }

    var userProfile: MHCodablePreferenceDescriptor<MHPreferenceKeysTestSupport.DemoCodablePreferenceValue> {
        .init(
            storageKey: "\(MHPreferenceKeysTestSupport.storageKeyPrefix).user-profile",
            defaultSelection: .suite(MHPreferenceKeysTestSupport.codableSuiteName)
        )
    }
}
