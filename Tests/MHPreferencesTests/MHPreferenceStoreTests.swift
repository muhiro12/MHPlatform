import Foundation
import MHPreferences
import Testing

struct MHPreferenceStoreTests {
    private enum Constants {
        static let namespace = "tests.preference-store"

        static let trueDefault = true
        static let falseDefault = false
        static let defaultIntValue = 20
        static let persistedIntValue = 7
        static let zeroValue = 0

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
        let key = MHBoolPreferenceKey(
            namespace: Constants.namespace,
            name: "bool-default-key",
            default: Constants.trueDefault
        )

        let value = store.bool(for: key)

        #expect(value == Constants.trueDefault)
    }

    @Test
    func bool_returns_stored_value_after_set() throws {
        let (store, _) = try makeStore(suiteName: "bool-set")
        let key = MHBoolPreferenceKey(
            namespace: Constants.namespace,
            name: "bool-set-key",
            default: Constants.falseDefault
        )

        store.set(Constants.trueDefault, for: key)

        #expect(store.bool(for: key) == Constants.trueDefault)
    }

    @Test
    func int_returns_default_value_when_unset() throws {
        let (store, _) = try makeStore(suiteName: "int-default")
        let key = MHIntPreferenceKey(
            namespace: Constants.namespace,
            name: "int-default-key",
            default: Constants.defaultIntValue
        )

        let value = store.int(for: key)

        #expect(value == Constants.defaultIntValue)
    }

    @Test
    func int_preserves_explicit_zero_value() throws {
        let (store, _) = try makeStore(suiteName: "int-zero")
        let key = MHIntPreferenceKey(
            namespace: Constants.namespace,
            name: "int-zero-key",
            default: Constants.defaultIntValue
        )

        store.set(Constants.zeroValue, for: key)

        #expect(store.int(for: key) == Constants.zeroValue)
    }

    @Test
    func string_round_trips() throws {
        let (store, _) = try makeStore(suiteName: "string-roundtrip")
        let key = MHStringPreferenceKey(
            namespace: Constants.namespace,
            name: "string-key"
        )
        let expectedValue = "hello"

        store.set(expectedValue, for: key)

        #expect(store.string(for: key) == expectedValue)
    }

    @Test
    func string_nil_removes_value() throws {
        let (store, userDefaults) = try makeStore(suiteName: "string-remove")
        let key = MHStringPreferenceKey(
            namespace: Constants.namespace,
            name: "string-remove-key"
        )

        store.set("value", for: key)
        store.set(nil, for: key)

        #expect(store.string(for: key) == nil)
        #expect(userDefaults.object(forKey: key.storageKey) == nil)
    }

    @Test
    func codable_round_trips_data_storage() throws {
        let (store, userDefaults) = try makeStore(suiteName: "codable-roundtrip")
        let key = MHCodablePreferenceKey<DemoPayload>(
            namespace: Constants.namespace,
            name: "codable-roundtrip-key"
        )
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
        let key = MHCodablePreferenceKey<DemoPayload>(
            namespace: Constants.namespace,
            name: "codable-non-data-key"
        )
        userDefaults.set("not-data", forKey: key.storageKey)

        let decodedValue = store.codable(for: key)

        #expect(decodedValue == nil)
    }

    @Test
    func codable_returns_nil_for_invalid_data() throws {
        let (store, userDefaults) = try makeStore(suiteName: "codable-invalid-data")
        let key = MHCodablePreferenceKey<DemoPayload>(
            namespace: Constants.namespace,
            name: "codable-invalid-data-key"
        )
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
        let boolKey = MHBoolPreferenceKey(
            namespace: Constants.namespace,
            name: "remove-bool"
        )
        let intKey = MHIntPreferenceKey(
            namespace: Constants.namespace,
            name: "remove-int"
        )
        let stringKey = MHStringPreferenceKey(
            namespace: Constants.namespace,
            name: "remove-string"
        )
        let codableKey = MHCodablePreferenceKey<DemoPayload>(
            namespace: Constants.namespace,
            name: "remove-codable"
        )
        let payload = DemoPayload(
            title: "payload",
            count: Constants.persistedIntValue
        )

        store.set(Constants.trueDefault, for: boolKey)
        store.set(Constants.persistedIntValue, for: intKey)
        store.set("value", for: stringKey)
        store.setCodable(payload, for: codableKey)

        store.remove(boolKey)
        store.remove(intKey)
        store.remove(stringKey)
        store.remove(codableKey)

        #expect(userDefaults.object(forKey: boolKey.storageKey) == nil)
        #expect(userDefaults.object(forKey: intKey.storageKey) == nil)
        #expect(userDefaults.object(forKey: stringKey.storageKey) == nil)
        #expect(userDefaults.object(forKey: codableKey.storageKey) == nil)
    }

    @Test
    func namespace_keeps_keys_isolated_even_with_same_name() throws {
        let (store, userDefaults) = try makeStore(suiteName: "namespace-safety")
        let primaryKey = MHBoolPreferenceKey(
            namespace: "tests.primary",
            name: "same-name",
            default: false
        )
        let secondaryKey = MHBoolPreferenceKey(
            namespace: "tests.secondary",
            name: "same-name",
            default: false
        )

        store.set(true, for: primaryKey)

        #expect(store.bool(for: primaryKey) == true)
        #expect(store.bool(for: secondaryKey) == false)
        #expect(userDefaults.object(forKey: primaryKey.storageKey) != nil)
        #expect(userDefaults.object(forKey: secondaryKey.storageKey) == nil)
    }

    private func makeStore(
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
}
