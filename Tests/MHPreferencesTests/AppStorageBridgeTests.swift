#if canImport(SwiftUI)
import Foundation
import MHPreferences
import SwiftUI
import Testing

struct AppStorageBridgeTests {
    private enum Constants {
        static let storageKeyPrefix = "tests.app-storage"

        static let boolDefaultValue = true
        static let intDefaultValue = 30
        static let intStoredValue = 12
        static let injectedBoolValue = true
    }

    private struct BoolHarness {
        @AppStorage private var value: Bool

        var wrappedValue: Bool {
            get {
                value
            }
            set {
                value = newValue
            }
        }

        init(
            key: MHBoolPreferenceKey,
            store: UserDefaults
        ) {
            _value = AppStorage(
                key,
                store: store
            )
        }

        init(
            key: MHBoolPreferenceKey,
            selection: MHUserDefaultsSelection
        ) {
            _value = AppStorage(
                key,
                selection: selection
            )
        }
    }

    private struct IntHarness {
        @AppStorage private var value: Int

        var wrappedValue: Int {
            get {
                value
            }
            set {
                value = newValue
            }
        }

        init(
            key: MHIntPreferenceKey,
            store: UserDefaults
        ) {
            _value = AppStorage(
                key,
                store: store
            )
        }
    }

    private struct StringHarness {
        @AppStorage private var value: String?

        var wrappedValue: String? {
            get {
                value
            }
            set {
                value = newValue
            }
        }

        init(
            key: MHStringPreferenceKey,
            store: UserDefaults
        ) {
            _value = AppStorage(
                key,
                store: store
            )
        }
    }

    private struct RequiredStringHarness {
        @AppStorage private var value: String

        var wrappedValue: String {
            get {
                value
            }
            set {
                value = newValue
            }
        }

        init(
            key: MHStringPreferenceKey,
            default defaultValue: String,
            store: UserDefaults
        ) {
            _value = AppStorage(
                key,
                default: defaultValue,
                store: store
            )
        }
    }

    private enum DemoRawStringValue: String {
        case first
        case second
    }

    private struct RawStringHarness {
        @AppStorage private var value: DemoRawStringValue

        var wrappedValue: DemoRawStringValue {
            get {
                value
            }
            set {
                value = newValue
            }
        }

        init(
            key: MHStringPreferenceKey,
            default defaultValue: DemoRawStringValue,
            store: UserDefaults
        ) {
            _value = AppStorage(
                key,
                default: defaultValue,
                store: store
            )
        }
    }

    @Test
    func bool_bridge_uses_default_value() throws {
        let userDefaults = try makeUserDefaults(suiteName: "bool-default")
        let key = makeBoolKey(
            "bool-default-key",
            default: Constants.boolDefaultValue
        )
        let harness = BoolHarness(
            key: key,
            store: userDefaults
        )

        #expect(harness.wrappedValue == Constants.boolDefaultValue)
    }

    @Test
    func int_bridge_uses_default_value() throws {
        let userDefaults = try makeUserDefaults(suiteName: "int-default")
        let key = makeIntKey(
            "int-default-key",
            default: Constants.intDefaultValue
        )
        let harness = IntHarness(
            key: key,
            store: userDefaults
        )

        #expect(harness.wrappedValue == Constants.intDefaultValue)
    }

    @Test
    func string_bridge_round_trips_and_removes_nil() throws {
        let userDefaults = try makeUserDefaults(suiteName: "string-roundtrip")
        let key = makeStringKey("string-roundtrip-key")
        var harness = StringHarness(
            key: key,
            store: userDefaults
        )

        #expect(harness.wrappedValue == nil)

        harness.wrappedValue = "value"
        #expect(userDefaults.string(forKey: key.storageKey) == "value")

        harness.wrappedValue = nil
        #expect(userDefaults.object(forKey: key.storageKey) == nil)
    }

    @Test
    func store_injection_is_respected() throws {
        let userDefaults = try makeUserDefaults(suiteName: "injected-store")
        let key = makeBoolKey("injected-store-key")
        var boolHarness = BoolHarness(
            key: key,
            store: userDefaults
        )
        let intKey = makeIntKey(
            "injected-int-key",
            default: Constants.intDefaultValue
        )
        var intHarness = IntHarness(
            key: intKey,
            store: userDefaults
        )

        boolHarness.wrappedValue = Constants.injectedBoolValue
        intHarness.wrappedValue = Constants.intStoredValue

        #expect(userDefaults.bool(forKey: key.storageKey) == Constants.injectedBoolValue)
        #expect(userDefaults.integer(forKey: intKey.storageKey) == Constants.intStoredValue)
    }

    @Test
    func selection_injection_is_respected() throws {
        let suiteName = "selection-store"
        let userDefaults = try makeUserDefaults(suiteName: suiteName)
        let key = makeBoolKey("selection-bool-key")
        var harness = BoolHarness(
            key: key,
            selection: .suite("  AppStorageBridgeTests.\(suiteName)\n")
        )

        harness.wrappedValue = Constants.injectedBoolValue

        #expect(userDefaults.bool(forKey: key.storageKey) == Constants.injectedBoolValue)
    }

    @Test
    func string_bridge_with_default_uses_default_then_round_trips() throws {
        let userDefaults = try makeUserDefaults(suiteName: "required-string")
        let key = makeStringKey("required-string-key")
        var harness = RequiredStringHarness(
            key: key,
            default: "fallback",
            store: userDefaults
        )

        #expect(harness.wrappedValue == "fallback")

        harness.wrappedValue = "stored"
        #expect(userDefaults.string(forKey: key.storageKey) == "stored")
    }

    @Test
    func raw_string_bridge_round_trips_existing_storage() throws {
        let userDefaults = try makeUserDefaults(suiteName: "raw-string")
        let key = makeStringKey("raw-string-key")
        userDefaults.set("second", forKey: key.storageKey)
        var harness = RawStringHarness(
            key: key,
            default: .first,
            store: userDefaults
        )

        #expect(harness.wrappedValue == .second)

        harness.wrappedValue = .first
        #expect(userDefaults.string(forKey: key.storageKey) == DemoRawStringValue.first.rawValue)
    }
}

private extension AppStorageBridgeTests {
    func makeUserDefaults(suiteName: String) throws -> UserDefaults {
        let resolvedSuiteName = "AppStorageBridgeTests.\(suiteName)"
        let userDefaults = try #require(
            UserDefaults(suiteName: resolvedSuiteName)
        )
        userDefaults.removePersistentDomain(forName: resolvedSuiteName)
        return userDefaults
    }

    func makeBoolKey(
        _ name: String,
        default defaultValue: Bool = false
    ) -> MHBoolPreferenceKey {
        .init(
            storageKey: "\(Constants.storageKeyPrefix).\(name)",
            default: defaultValue
        )
    }

    func makeIntKey(
        _ name: String,
        default defaultValue: Int = .zero
    ) -> MHIntPreferenceKey {
        .init(
            storageKey: "\(Constants.storageKeyPrefix).\(name)",
            default: defaultValue
        )
    }

    func makeStringKey(_ name: String) -> MHStringPreferenceKey {
        .init(storageKey: "\(Constants.storageKeyPrefix).\(name)")
    }
}
#endif
