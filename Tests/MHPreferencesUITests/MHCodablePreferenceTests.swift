#if canImport(SwiftUI)
import Foundation
import MHPreferences
@testable import MHPreferencesTestSupport
import MHPreferencesUI
import SwiftUI
import Testing

struct MHCodablePreferenceTests {
    private enum Constants {
        static let invalidData = Data([0x00, 0xFF])
    }

    private struct OptionalDescriptorHarness {
        @MHOptionalCodablePreference private var value: MHPreferenceDescriptorsTestSupport.DemoCodablePreferenceValue?

        var wrappedValue: MHPreferenceDescriptorsTestSupport.DemoCodablePreferenceValue? {
            get {
                value
            }
            set {
                value = newValue
            }
        }

        var binding: Binding<MHPreferenceDescriptorsTestSupport.DemoCodablePreferenceValue?> {
            $value
        }

        init(
            descriptor: MHCodablePreferenceDescriptor<MHPreferenceDescriptorsTestSupport.DemoCodablePreferenceValue>,
            store: UserDefaults
        ) {
            _value = MHOptionalCodablePreference(
                descriptor,
                store: store
            )
        }
    }

    private struct OptionalKeyPathHarness {
        @MHOptionalCodablePreference private var value: MHPreferenceDescriptorsTestSupport.DemoCodablePreferenceValue?

        var wrappedValue: MHPreferenceDescriptorsTestSupport.DemoCodablePreferenceValue? {
            get {
                value
            }
            set {
                value = newValue
            }
        }

        var binding: Binding<MHPreferenceDescriptorsTestSupport.DemoCodablePreferenceValue?> {
            $value
        }

        init(store: UserDefaults) {
            _value = MHOptionalCodablePreference(
                \.userProfile,
                store: store
            )
        }
    }

    private struct RequiredDescriptorHarness {
        @MHCodablePreference private var value: MHPreferenceDescriptorsTestSupport.DemoCodablePreferenceValue

        var wrappedValue: MHPreferenceDescriptorsTestSupport.DemoCodablePreferenceValue {
            get {
                value
            }
            set {
                value = newValue
            }
        }

        init(
            descriptor: MHCodablePreferenceDescriptor<MHPreferenceDescriptorsTestSupport.DemoCodablePreferenceValue>,
            default defaultValue: MHPreferenceDescriptorsTestSupport.DemoCodablePreferenceValue,
            store: UserDefaults
        ) {
            _value = MHCodablePreference(
                descriptor,
                default: defaultValue,
                store: store
            )
        }
    }

    private struct RequiredKeyPathHarness {
        @MHCodablePreference private var value: MHPreferenceDescriptorsTestSupport.DemoCodablePreferenceValue

        var wrappedValue: MHPreferenceDescriptorsTestSupport.DemoCodablePreferenceValue {
            get {
                value
            }
            set {
                value = newValue
            }
        }

        var binding: Binding<MHPreferenceDescriptorsTestSupport.DemoCodablePreferenceValue> {
            $value
        }

        init(
            default defaultValue: MHPreferenceDescriptorsTestSupport.DemoCodablePreferenceValue,
            store: UserDefaults
        ) {
            _value = MHCodablePreference(
                \.userProfile,
                default: defaultValue,
                store: store
            )
        }
    }

    private let defaultValue = MHPreferenceDescriptorsTestSupport.DemoCodablePreferenceValue(
        title: "default",
        count: 1
    )
    private let storedValue = MHPreferenceDescriptorsTestSupport.DemoCodablePreferenceValue(
        title: "stored",
        count: 4
    )

    @Test
    func optional_descriptor_bridge_round_trips_and_removes_nil() throws {
        let userDefaults = try makeUserDefaults(suiteName: "optional-direct")
        var harness = OptionalDescriptorHarness(
            descriptor: MHPreferenceDescriptors().userProfile,
            store: userDefaults
        )

        #expect(harness.wrappedValue == nil)

        harness.wrappedValue = storedValue
        #expect(readStoredValue(from: userDefaults) == storedValue)

        harness.wrappedValue = nil
        #expect(
            userDefaults.object(
                forKey: MHPreferenceDescriptors().userProfile.storageKey
            ) == nil
        )
    }

    @Test
    func optional_key_path_bridge_updates_storage_through_binding() throws {
        let userDefaults = try makeUserDefaults(suiteName: "optional-key-path")
        let harness = OptionalKeyPathHarness(store: userDefaults)

        harness.binding.wrappedValue = storedValue

        #expect(harness.wrappedValue == storedValue)
        #expect(readStoredValue(from: userDefaults) == storedValue)
    }

    @Test
    func optional_wrapper_returns_nil_for_decode_failure() throws {
        let userDefaults = try makeUserDefaults(suiteName: "optional-invalid")
        userDefaults.set(
            Constants.invalidData,
            forKey: MHPreferenceDescriptors().userProfile.storageKey
        )
        let harness = OptionalDescriptorHarness(
            descriptor: MHPreferenceDescriptors().userProfile,
            store: userDefaults
        )

        #expect(harness.wrappedValue == nil)
    }

    @Test
    func required_descriptor_bridge_uses_default_when_storage_is_missing_or_invalid() throws {
        let userDefaults = try makeUserDefaults(suiteName: "required-direct")
        let harness = RequiredDescriptorHarness(
            descriptor: MHPreferenceDescriptors().userProfile,
            default: defaultValue,
            store: userDefaults
        )

        #expect(harness.wrappedValue == defaultValue)

        userDefaults.set(
            Constants.invalidData,
            forKey: MHPreferenceDescriptors().userProfile.storageKey
        )

        let invalidHarness = RequiredDescriptorHarness(
            descriptor: MHPreferenceDescriptors().userProfile,
            default: defaultValue,
            store: userDefaults
        )

        #expect(invalidHarness.wrappedValue == defaultValue)
    }

    @Test
    func required_key_path_bridge_round_trips_and_supports_binding_updates() throws {
        let userDefaults = try makeUserDefaults(suiteName: "required-key-path")
        let harness = RequiredKeyPathHarness(
            default: defaultValue,
            store: userDefaults
        )

        harness.binding.wrappedValue = storedValue

        #expect(harness.wrappedValue == storedValue)
        #expect(readStoredValue(from: userDefaults) == storedValue)
    }

    @Test
    func explicit_store_injection_keeps_other_domains_untouched() throws {
        let firstStore = try makeUserDefaults(suiteName: "store-injection.first")
        let secondStore = try makeUserDefaults(suiteName: "store-injection.second")
        var harness = OptionalKeyPathHarness(store: firstStore)

        harness.wrappedValue = storedValue

        #expect(readStoredValue(from: firstStore) == storedValue)
        #expect(readStoredValue(from: secondStore) == nil)
    }
}

private extension MHCodablePreferenceTests {
    func makeUserDefaults(suiteName: String) throws -> UserDefaults {
        let resolvedSuiteName = "MHCodablePreferenceTests.\(suiteName)"
        let userDefaults = try #require(
            UserDefaults(suiteName: resolvedSuiteName)
        )
        userDefaults.removePersistentDomain(forName: resolvedSuiteName)
        return userDefaults
    }

    func readStoredValue(
        from userDefaults: UserDefaults
    ) -> MHPreferenceDescriptorsTestSupport.DemoCodablePreferenceValue? {
        MHPreferenceStore(userDefaults: userDefaults).codable(
            for: MHPreferenceDescriptors().userProfile
        )
    }
}
#endif
