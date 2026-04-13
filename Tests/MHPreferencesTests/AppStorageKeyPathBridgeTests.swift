#if canImport(SwiftUI)
import Foundation
import MHPreferences
import SwiftUI
import Testing

struct AppStorageKeyPathBridgeTests {
    private enum Constants {
        static let storedDateValue = Date(timeIntervalSinceReferenceDate: 8)
    }

    private enum DemoRawStringValue: String {
        case first
        case second
    }

    private struct TypeInferenceSnapshot {
        let hasSeenOnboarding: Bool
        let launchCount: Int
        let displayName: String?
        let requiredDisplayName: String
        let rawDisplayName: DemoRawStringValue
        let lastSeenAt: Date?
    }

    private struct TypeInferenceHarness {
        @AppStorage(\.hasSeenOnboarding)
        private var hasSeenOnboarding

        @AppStorage(\.launchCount)
        private var launchCount

        @AppStorage(\.displayName)
        private var displayName

        @AppStorage(\.displayName, default: "fallback")
        private var requiredDisplayName

        @AppStorage(\.displayName, default: DemoRawStringValue.first)
        private var rawDisplayName

        @AppStorage(\.lastSeenAt)
        private var lastSeenAt

        var snapshot: TypeInferenceSnapshot {
            .init(
                hasSeenOnboarding: hasSeenOnboarding,
                launchCount: launchCount,
                displayName: displayName,
                requiredDisplayName: requiredDisplayName,
                rawDisplayName: rawDisplayName,
                lastSeenAt: lastSeenAt
            )
        }
    }

    private struct DateHarness {
        @AppStorage private var value: Date?

        var wrappedValue: Date? {
            get {
                value
            }
            set {
                value = newValue
            }
        }

        init(store: UserDefaults) {
            _value = AppStorage(
                \.lastSeenAt,
                store: store
            )
        }
    }

    private struct AliasHarness {
        @AppStorage(.hasSeenOnboarding)
        private var hasSeenOnboarding

        var wrappedValue: Bool {
            hasSeenOnboarding
        }
    }

    @Test
    func key_path_initializer_supports_type_inference() throws {
        try clearDefaultSelectionDomains()

        let harness = TypeInferenceHarness()

        #expect(harness.snapshot.hasSeenOnboarding)
        #expect(harness.snapshot.launchCount == 3)
        #expect(harness.snapshot.displayName == nil)
        #expect(harness.snapshot.requiredDisplayName == "fallback")
        #expect(harness.snapshot.rawDisplayName == .first)
        #expect(harness.snapshot.lastSeenAt == nil)
    }

    @Test
    func key_path_bridge_respects_store_injection() throws {
        let userDefaults = try makeUserDefaults(suiteName: "date-store")
        var harness = DateHarness(store: userDefaults)

        #expect(harness.wrappedValue == nil)

        harness.wrappedValue = Constants.storedDateValue
        #expect(
            userDefaults.object(
                forKey: MHPreferenceDescriptors().lastSeenAt.storageKey
            ) as? Date == Constants.storedDateValue
        )
    }

    @Test
    func app_local_static_alias_supports_shorthand() throws {
        try clearPersistentDomain(
            named: MHPreferenceDescriptorsTestSupport.boolSuiteName
        )

        let harness = AliasHarness()

        #expect(harness.wrappedValue)
    }
}

private extension AppStorageKeyPathBridgeTests {
    func clearDefaultSelectionDomains() throws {
        try clearPersistentDomain(named: MHPreferenceDescriptorsTestSupport.boolSuiteName)
        try clearPersistentDomain(named: MHPreferenceDescriptorsTestSupport.intSuiteName)
        try clearPersistentDomain(named: MHPreferenceDescriptorsTestSupport.stringSuiteName)
        try clearPersistentDomain(named: MHPreferenceDescriptorsTestSupport.dateSuiteName)
    }

    func clearPersistentDomain(named suiteName: String) throws {
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        userDefaults.removePersistentDomain(forName: suiteName)
    }

    func makeUserDefaults(suiteName: String) throws -> UserDefaults {
        let resolvedSuiteName = "AppStorageKeyPathBridgeTests.\(suiteName)"
        let userDefaults = try #require(
            UserDefaults(suiteName: resolvedSuiteName)
        )
        userDefaults.removePersistentDomain(forName: resolvedSuiteName)
        return userDefaults
    }
}

private extension MHBoolPreferenceDescriptor {
    static var hasSeenOnboarding: Self {
        MHPreferenceDescriptors().hasSeenOnboarding
    }
}
#endif
