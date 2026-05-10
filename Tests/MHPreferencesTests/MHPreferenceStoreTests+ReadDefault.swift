import MHPreferences
import Testing

extension MHPreferenceStoreTests {
    @Test
    func int_returns_read_default_override_when_unset() throws {
        let (store, _) = try makeStore(suiteName: "int-read-default")
        let key = makeIntKey(
            "int-read-default-key",
            default: Constants.defaultIntValue
        )

        let value = store.int(
            for: key,
            default: Constants.readDefaultIntValue
        )

        #expect(value == Constants.readDefaultIntValue)
    }

    @Test
    func int_read_default_preserves_explicit_zero_value() throws {
        let (store, _) = try makeStore(suiteName: "int-read-default-zero")
        let key = makeIntKey(
            "int-read-default-zero-key",
            default: Constants.defaultIntValue
        )

        store.set(Constants.zeroValue, for: key)

        #expect(
            store.int(
                for: key,
                default: Constants.readDefaultIntValue
            ) == Constants.zeroValue
        )
    }

    @Test
    func string_returns_read_default_override_when_unset() throws {
        let (store, _) = try makeStore(suiteName: "string-read-default")
        let key = makeStringKey("string-read-default-key")

        let value = store.string(
            for: key,
            default: Constants.readDefaultStringValue
        )

        #expect(value == Constants.readDefaultStringValue)
    }

    @Test
    func string_read_default_preserves_stored_empty_string() throws {
        let (store, _) = try makeStore(suiteName: "string-read-default-empty")
        let key = makeStringKey("string-read-default-empty-key")

        store.set("", for: key)

        #expect(
            store.string(
                for: key,
                default: Constants.readDefaultStringValue
            ).isEmpty
        )
    }

    @Test
    func string_read_default_preserves_stored_string() throws {
        let (store, _) = try makeStore(suiteName: "string-read-default-stored")
        let key = makeStringKey("string-read-default-stored-key")

        store.set("USD", for: key)

        #expect(
            store.string(
                for: key,
                default: Constants.readDefaultStringValue
            ) == "USD"
        )
    }
}
