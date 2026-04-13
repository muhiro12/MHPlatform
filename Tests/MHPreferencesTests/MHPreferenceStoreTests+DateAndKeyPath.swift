import Foundation
import MHPreferences
import Testing

extension MHPreferenceStoreTests {
    @Test
    func date_round_trips_and_removes_nil() throws {
        let (store, userDefaults) = try makeStore(suiteName: "date-roundtrip")
        let key = makeDateKey("date-roundtrip-key")

        store.set(Constants.persistedDateValue, for: key)

        #expect(store.date(for: key) == Constants.persistedDateValue)
        #expect(
            userDefaults.object(
                forKey: key.storageKey
            ) as? Date == Constants.persistedDateValue
        )

        store.set(Date?.none, for: key)

        #expect(store.date(for: key) == nil)
        #expect(userDefaults.object(forKey: key.storageKey) == nil)
    }

    @Test
    func key_namespace_overloads_round_trip_supported_value_types() throws {
        let (store, userDefaults) = try makeStore(suiteName: "key-namespace")
        let expectedProfile = MHPreferenceKeysTestSupport.DemoCodablePreferenceValue(
            title: "profile",
            count: Constants.persistedIntValue
        )

        store.set(false, for: \MHPreferenceKeys.hasSeenOnboarding)
        store.set(Constants.persistedIntValue, for: \MHPreferenceKeys.launchCount)
        store.set("display-name", for: \MHPreferenceKeys.displayName)
        store.set(Constants.persistedDateValue, for: \MHPreferenceKeys.lastSeenAt)
        store.setCodable(expectedProfile, for: \MHPreferenceKeys.userProfile)

        #expect(store.bool(for: \MHPreferenceKeys.hasSeenOnboarding) == false)
        #expect(store.int(for: \MHPreferenceKeys.launchCount) == Constants.persistedIntValue)
        #expect(store.string(for: \MHPreferenceKeys.displayName) == "display-name")
        #expect(store.date(for: \MHPreferenceKeys.lastSeenAt) == Constants.persistedDateValue)
        #expect(store.codable(for: \MHPreferenceKeys.userProfile) == expectedProfile)
        #expect(
            userDefaults.object(
                forKey: MHPreferenceKeys().lastSeenAt.storageKey
            ) as? Date == Constants.persistedDateValue
        )
    }

    func makeDateKey(
        _ name: String,
        defaultSelection: MHUserDefaultsSelection = .standard
    ) -> MHDatePreferenceDescriptor {
        .init(
            storageKey: "\(Constants.storageKeyPrefix).\(name)",
            defaultSelection: defaultSelection
        )
    }
}
