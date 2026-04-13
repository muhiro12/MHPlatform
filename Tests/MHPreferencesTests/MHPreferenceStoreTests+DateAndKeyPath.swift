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
    func descriptor_namespace_overloads_round_trip_supported_value_types() throws {
        let (store, userDefaults) = try makeStore(suiteName: "descriptor-namespace")
        let expectedProfile = MHPreferenceDescriptorsTestSupport.DemoCodablePreferenceValue(
            title: "profile",
            count: Constants.persistedIntValue
        )

        store.set(false, for: \MHPreferenceDescriptors.hasSeenOnboarding)
        store.set(Constants.persistedIntValue, for: \MHPreferenceDescriptors.launchCount)
        store.set("display-name", for: \MHPreferenceDescriptors.displayName)
        store.set(Constants.persistedDateValue, for: \MHPreferenceDescriptors.lastSeenAt)
        store.setCodable(expectedProfile, for: \MHPreferenceDescriptors.userProfile)

        #expect(store.bool(for: \MHPreferenceDescriptors.hasSeenOnboarding) == false)
        #expect(store.int(for: \MHPreferenceDescriptors.launchCount) == Constants.persistedIntValue)
        #expect(store.string(for: \MHPreferenceDescriptors.displayName) == "display-name")
        #expect(store.date(for: \MHPreferenceDescriptors.lastSeenAt) == Constants.persistedDateValue)
        #expect(store.codable(for: \MHPreferenceDescriptors.userProfile) == expectedProfile)
        #expect(
            userDefaults.object(
                forKey: MHPreferenceDescriptors().lastSeenAt.storageKey
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
