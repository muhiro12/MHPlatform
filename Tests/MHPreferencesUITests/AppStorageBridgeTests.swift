#if canImport(SwiftUI)
import Foundation
import MHPreferences
import MHPreferencesUI
import SwiftUI
import Testing

struct AppStorageBridgeTests {
    @Test
    func direct_descriptor_initializer_supports_type_inference() throws {
        try AppStorageBridgeTestSupport.clearPersistentDomain(
            named: AppStorageBridgeHarnesses.TypeInferenceHarness.boolSuiteName
        )
        try AppStorageBridgeTestSupport.clearPersistentDomain(
            named: AppStorageBridgeHarnesses.TypeInferenceHarness.intSuiteName
        )
        try AppStorageBridgeTestSupport.clearPersistentDomain(
            named: AppStorageBridgeHarnesses.TypeInferenceHarness.stringSuiteName
        )
        try AppStorageBridgeTestSupport.clearPersistentDomain(
            named: AppStorageBridgeHarnesses.TypeInferenceHarness.requiredStringSuiteName
        )
        try AppStorageBridgeTestSupport.clearPersistentDomain(
            named: AppStorageBridgeHarnesses.TypeInferenceHarness.rawStringSuiteName
        )
        try AppStorageBridgeTestSupport.clearPersistentDomain(
            named: AppStorageBridgeHarnesses.TypeInferenceHarness.dateSuiteName
        )

        let harness = AppStorageBridgeHarnesses.TypeInferenceHarness()

        #expect(
            harness.snapshot.boolValue
                == AppStorageBridgeTestSupport.Constants.boolDefaultValue
        )
        #expect(
            harness.snapshot.intValue
                == AppStorageBridgeTestSupport.Constants.intDefaultValue
        )
        #expect(harness.snapshot.stringValue == nil)
        #expect(harness.snapshot.requiredStringValue == "fallback")
        #expect(harness.snapshot.rawStringValue == .first)
        #expect(harness.snapshot.dateValue == nil)
    }

    @Test
    func bool_bridge_uses_default_value() throws {
        let userDefaults = try AppStorageBridgeTestSupport.makeUserDefaults(
            suiteName: "bool-default"
        )
        let key = AppStorageBridgeTestSupport.makeBoolKey(
            "bool-default-key",
            default: AppStorageBridgeTestSupport.Constants.boolDefaultValue
        )
        let harness = AppStorageBridgeHarnesses.BoolHarness(
            key: key,
            store: userDefaults
        )

        #expect(
            harness.wrappedValue
                == AppStorageBridgeTestSupport.Constants.boolDefaultValue
        )
    }

    @Test
    func int_bridge_uses_default_value() throws {
        let userDefaults = try AppStorageBridgeTestSupport.makeUserDefaults(
            suiteName: "int-default"
        )
        let key = AppStorageBridgeTestSupport.makeIntKey(
            "int-default-key",
            default: AppStorageBridgeTestSupport.Constants.intDefaultValue
        )
        let harness = AppStorageBridgeHarnesses.IntHarness(
            key: key,
            store: userDefaults
        )

        #expect(
            harness.wrappedValue
                == AppStorageBridgeTestSupport.Constants.intDefaultValue
        )
    }

    @Test
    func string_bridge_round_trips_and_removes_nil() throws {
        let userDefaults = try AppStorageBridgeTestSupport.makeUserDefaults(
            suiteName: "string-roundtrip"
        )
        let key = AppStorageBridgeTestSupport.makeStringKey("string-roundtrip-key")
        var harness = AppStorageBridgeHarnesses.StringHarness(
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
        let userDefaults = try AppStorageBridgeTestSupport.makeUserDefaults(
            suiteName: "injected-store"
        )
        let key = AppStorageBridgeTestSupport.makeBoolKey("injected-store-key")
        var boolHarness = AppStorageBridgeHarnesses.BoolHarness(
            key: key,
            store: userDefaults
        )
        let intKey = AppStorageBridgeTestSupport.makeIntKey(
            "injected-int-key",
            default: AppStorageBridgeTestSupport.Constants.intDefaultValue
        )
        var intHarness = AppStorageBridgeHarnesses.IntHarness(
            key: intKey,
            store: userDefaults
        )

        boolHarness.wrappedValue = AppStorageBridgeTestSupport.Constants.injectedBoolValue
        intHarness.wrappedValue = AppStorageBridgeTestSupport.Constants.intStoredValue

        #expect(
            userDefaults.bool(forKey: key.storageKey)
                == AppStorageBridgeTestSupport.Constants.injectedBoolValue
        )
        #expect(
            userDefaults.integer(forKey: intKey.storageKey)
                == AppStorageBridgeTestSupport.Constants.intStoredValue
        )
    }

    @Test
    func default_selection_is_respected() throws {
        let suiteName = "default-selection-store"
        let userDefaults = try AppStorageBridgeTestSupport.makeUserDefaults(
            suiteName: suiteName
        )
        let key = AppStorageBridgeTestSupport.makeBoolKey(
            "selection-bool-key",
            defaultSelection: .suite("  AppStorageBridgeTests.\(suiteName)\n")
        )
        var harness = AppStorageBridgeHarnesses.BoolHarness(
            key: key
        )

        harness.wrappedValue = AppStorageBridgeTestSupport.Constants.injectedBoolValue

        #expect(
            userDefaults.bool(forKey: key.storageKey)
                == AppStorageBridgeTestSupport.Constants.injectedBoolValue
        )
    }

    @Test
    func string_bridge_with_default_uses_default_then_round_trips() throws {
        let userDefaults = try AppStorageBridgeTestSupport.makeUserDefaults(
            suiteName: "required-string"
        )
        let key = AppStorageBridgeTestSupport.makeStringKey("required-string-key")
        var harness = AppStorageBridgeHarnesses.RequiredStringHarness(
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
        let userDefaults = try AppStorageBridgeTestSupport.makeUserDefaults(
            suiteName: "raw-string"
        )
        let key = AppStorageBridgeTestSupport.makeStringKey("raw-string-key")
        userDefaults.set("second", forKey: key.storageKey)
        var harness = AppStorageBridgeHarnesses.RawStringHarness(
            key: key,
            default: .first,
            store: userDefaults
        )

        #expect(harness.wrappedValue == .second)

        harness.wrappedValue = .first
        #expect(
            userDefaults.string(forKey: key.storageKey)
                == AppStorageBridgeHarnesses.DemoRawStringValue.first.rawValue
        )
    }

    @Test
    func date_bridge_round_trips_and_removes_nil() throws {
        let userDefaults = try AppStorageBridgeTestSupport.makeUserDefaults(
            suiteName: "date-roundtrip"
        )
        let key = AppStorageBridgeTestSupport.makeDateKey("date-roundtrip-key")
        var harness = AppStorageBridgeHarnesses.DateHarness(
            key: key,
            store: userDefaults
        )

        #expect(harness.wrappedValue == nil)

        harness.wrappedValue = AppStorageBridgeTestSupport.Constants.directDateValue
        #expect(
            userDefaults.object(forKey: key.storageKey) as? Date
                == AppStorageBridgeTestSupport.Constants.directDateValue
        )

        harness.wrappedValue = nil
        #expect(userDefaults.object(forKey: key.storageKey) == nil)
    }
}
#endif
