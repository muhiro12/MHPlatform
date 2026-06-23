import Foundation
import MHPreferences

enum MHPreferenceDescriptorsTestSupport {
    struct DemoCodablePreferenceValue: Codable, Equatable, Sendable {
        let title: String
        let count: Int
    }

    static let storageKeyPrefix = "tests.preference-descriptors"
    static let boolSuiteName = "MHPreferencesTests.PreferenceDescriptors.bool"
    static let intSuiteName = "MHPreferencesTests.PreferenceDescriptors.int"
    static let stringSuiteName = "MHPreferencesTests.PreferenceDescriptors.string"
    static let dateSuiteName = "MHPreferencesTests.PreferenceDescriptors.date"
    static let codableSuiteName = "MHPreferencesTests.PreferenceDescriptors.codable"
    static let launchCountDefaultValue = 3
}

extension MHPreferenceDescriptors {
    var hasSeenOnboarding: MHBoolPreferenceDescriptor {
        .init(
            storageKey: "\(MHPreferenceDescriptorsTestSupport.storageKeyPrefix).has-seen-onboarding",
            defaultSelection: .suite(MHPreferenceDescriptorsTestSupport.boolSuiteName),
            default: true
        )
    }

    var launchCount: MHIntPreferenceDescriptor {
        .init(
            storageKey: "\(MHPreferenceDescriptorsTestSupport.storageKeyPrefix).launch-count",
            defaultSelection: .suite(MHPreferenceDescriptorsTestSupport.intSuiteName),
            default: MHPreferenceDescriptorsTestSupport.launchCountDefaultValue
        )
    }

    var displayName: MHStringPreferenceDescriptor {
        .init(
            storageKey: "\(MHPreferenceDescriptorsTestSupport.storageKeyPrefix).display-name",
            defaultSelection: .suite(MHPreferenceDescriptorsTestSupport.stringSuiteName)
        )
    }

    var lastSeenAt: MHDatePreferenceDescriptor {
        .init(
            storageKey: "\(MHPreferenceDescriptorsTestSupport.storageKeyPrefix).last-seen-at",
            defaultSelection: .suite(MHPreferenceDescriptorsTestSupport.dateSuiteName)
        )
    }

    var userProfile: MHCodablePreferenceDescriptor<MHPreferenceDescriptorsTestSupport.DemoCodablePreferenceValue> {
        .init(
            storageKey: "\(MHPreferenceDescriptorsTestSupport.storageKeyPrefix).user-profile",
            defaultSelection: .suite(MHPreferenceDescriptorsTestSupport.codableSuiteName)
        )
    }
}
