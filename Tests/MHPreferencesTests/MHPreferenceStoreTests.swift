import Foundation
import MHPreferences
import Testing

struct MHPreferenceStoreTests {
    enum Constants {
        static let storageKeyPrefix = "tests.preference-store"

        static let trueDefault = true
        static let falseDefault = false
        static let defaultIntValue = 20
        static let persistedIntValue = 7
        static let zeroValue = 0
        static let persistedDateValue = Date(timeIntervalSinceReferenceDate: 8)

        static let invalidDataByte0: UInt8 = 0x00
        static let invalidDataByte1: UInt8 = 0xFF
    }

    private struct DemoPayload: Codable, Equatable, Sendable {
        let title: String
        let count: Int
    }

    @Test
    func bool_returns_default_value_when_unset() throws {
        let (store, _) = try makeStore(suiteName: "bool-default")
        let key = makeBoolKey(
            "bool-default-key",
            default: Constants.trueDefault
        )

        let value = store.bool(for: key)

        #expect(value == Constants.trueDefault)
    }

    @Test
    func bool_returns_stored_value_after_set() throws {
        let (store, _) = try makeStore(suiteName: "bool-set")
        let key = makeBoolKey(
            "bool-set-key",
            default: Constants.falseDefault
        )

        store.set(Constants.trueDefault, for: key)

        #expect(store.bool(for: key) == Constants.trueDefault)
    }

    @Test
    func int_returns_default_value_when_unset() throws {
        let (store, _) = try makeStore(suiteName: "int-default")
        let key = makeIntKey(
            "int-default-key",
            default: Constants.defaultIntValue
        )

        let value = store.int(for: key)

        #expect(value == Constants.defaultIntValue)
    }

    @Test
    func int_preserves_explicit_zero_value() throws {
        let (store, _) = try makeStore(suiteName: "int-zero")
        let key = makeIntKey(
            "int-zero-key",
            default: Constants.defaultIntValue
        )

        store.set(Constants.zeroValue, for: key)

        #expect(store.int(for: key) == Constants.zeroValue)
    }

    @Test
    func string_round_trips() throws {
        let (store, _) = try makeStore(suiteName: "string-roundtrip")
        let key = makeStringKey("string-key")
        let expectedValue = "hello"

        store.set(expectedValue, for: key)

        #expect(store.string(for: key) == expectedValue)
    }

    @Test
    func string_nil_removes_value() throws {
        let (store, userDefaults) = try makeStore(suiteName: "string-remove")
        let key = makeStringKey("string-remove-key")

        store.set("value", for: key)
        store.set(nil, for: key)

        #expect(store.string(for: key) == nil)
        #expect(userDefaults.object(forKey: key.storageKey) == nil)
    }

    @Test
    func codable_round_trips_data_storage() throws {
        let (store, userDefaults) = try makeStore(suiteName: "codable-roundtrip")
        let key = makeCodableKey("codable-roundtrip-key")
        let expectedValue = DemoPayload(
            title: "rent",
            count: Constants.persistedIntValue
        )

        store.setCodable(expectedValue, for: key)
        let decodedValue = store.codable(for: key)
        let rawStoredValue = userDefaults.object(forKey: key.storageKey)

        #expect(decodedValue == expectedValue)
        #expect(rawStoredValue is Data)
    }

    @Test
    func codable_returns_nil_for_non_data_storage() throws {
        let (store, userDefaults) = try makeStore(suiteName: "codable-non-data")
        let key = makeCodableKey("codable-non-data-key")
        userDefaults.set("not-data", forKey: key.storageKey)

        let decodedValue = store.codable(for: key)

        #expect(decodedValue == nil)
    }

    @Test
    func codable_returns_nil_for_invalid_data() throws {
        let (store, userDefaults) = try makeStore(suiteName: "codable-invalid-data")
        let key = makeCodableKey("codable-invalid-data-key")
        userDefaults.set(
            Data([Constants.invalidDataByte0, Constants.invalidDataByte1]),
            forKey: key.storageKey
        )

        let decodedValue = store.codable(for: key)

        #expect(decodedValue == nil)
    }

    @Test
    func remove_supports_all_key_types() throws {
        let (store, userDefaults) = try makeStore(suiteName: "remove-all")
        let boolKey = makeBoolKey("remove-bool")
        let intKey = makeIntKey("remove-int")
        let stringKey = makeStringKey("remove-string")
        let dateKey = makeDateKey("remove-date")
        let codableKey = makeCodableKey("remove-codable")
        let payload = DemoPayload(
            title: "payload",
            count: Constants.persistedIntValue
        )

        store.set(Constants.trueDefault, for: boolKey)
        store.set(Constants.persistedIntValue, for: intKey)
        store.set("value", for: stringKey)
        store.set(Constants.persistedDateValue, for: dateKey)
        store.setCodable(payload, for: codableKey)

        store.remove(boolKey)
        store.remove(intKey)
        store.remove(stringKey)
        store.remove(dateKey)
        store.remove(codableKey)

        #expect(userDefaults.object(forKey: boolKey.storageKey) == nil)
        #expect(userDefaults.object(forKey: intKey.storageKey) == nil)
        #expect(userDefaults.object(forKey: stringKey.storageKey) == nil)
        #expect(userDefaults.object(forKey: dateKey.storageKey) == nil)
        #expect(userDefaults.object(forKey: codableKey.storageKey) == nil)
    }

    @Test
    func storage_key_is_the_public_contract() {
        let boolKey = MHBoolPreferenceDescriptor(
            storageKey: "opaque-bool",
            defaultSelection: .standard
        )
        let intKey = MHIntPreferenceDescriptor(
            storageKey: "opaque-int",
            defaultSelection: .standard
        )
        let stringKey = MHStringPreferenceDescriptor(
            storageKey: "opaque-string",
            defaultSelection: .standard
        )
        let dateKey = MHDatePreferenceDescriptor(
            storageKey: "opaque-date",
            defaultSelection: .standard
        )
        let codableKey = MHCodablePreferenceDescriptor<DemoPayload>(
            storageKey: "opaque-codable",
            defaultSelection: .standard
        )

        #expect(boolKey.storageKey == "opaque-bool")
        #expect(intKey.storageKey == "opaque-int")
        #expect(stringKey.storageKey == "opaque-string")
        #expect(dateKey.storageKey == "opaque-date")
        #expect(codableKey.storageKey == "opaque-codable")
    }

    @Test
    func contains_tracks_presence_changes() throws {
        let (store, _) = try makeStore(suiteName: "contains")
        let key = makeBoolKey("contains-key")

        #expect(!store.contains(key))

        store.set(true, for: key)
        #expect(store.contains(key))

        store.remove(key)
        #expect(!store.contains(key))
    }

    @Test
    func unbound_store_uses_descriptor_default_selection() throws {
        let suiteName = "MHPreferenceStoreTests.selection.\(UUID().uuidString)"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        userDefaults.removePersistentDomain(forName: suiteName)
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }
        let store = MHPreferenceStore()
        let key = makeBoolKey(
            "selection-key",
            defaultSelection: .suite("  \(suiteName)\n")
        )

        store.set(true, for: key)

        #expect(userDefaults.bool(forKey: key.storageKey))
    }

    func makeStore(
        suiteName: String
    ) throws -> (MHPreferenceStore, UserDefaults) {
        let resolvedSuiteName = "MHPreferenceStoreTests.\(suiteName)"
        let userDefaults = try #require(
            UserDefaults(suiteName: resolvedSuiteName)
        )
        userDefaults.removePersistentDomain(forName: resolvedSuiteName)
        let store = MHPreferenceStore(userDefaults: userDefaults)
        return (store, userDefaults)
    }

    func makeBoolKey(
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

    func makeIntKey(
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

    func makeStringKey(
        _ name: String,
        defaultSelection: MHUserDefaultsSelection = .standard
    ) -> MHStringPreferenceDescriptor {
        .init(
            storageKey: "\(Constants.storageKeyPrefix).\(name)",
            defaultSelection: defaultSelection
        )
    }

    private func makeCodableKey(
        _ name: String,
        defaultSelection: MHUserDefaultsSelection = .standard
    ) -> MHCodablePreferenceDescriptor<DemoPayload> {
        .init(
            storageKey: "\(Constants.storageKeyPrefix).\(name)",
            defaultSelection: defaultSelection
        )
    }
}
