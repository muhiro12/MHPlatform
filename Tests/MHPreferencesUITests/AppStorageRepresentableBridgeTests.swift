#if canImport(SwiftUI)
import Foundation
import MHPreferences
import MHPreferencesUI
import SwiftUI
import Testing

struct AppStorageRepresentableBridgeTests {
    private struct BoolRepresentableKey: MHBoolPrefDescriptorRepresentable {
        let preferenceDescriptor: MHBoolPreferenceDescriptor
    }

    private struct IntRepresentableKey: MHIntPrefDescriptorRepresentable {
        let storageKey: String
        let defaultSelection: MHUserDefaultsSelection

        func preferenceDescriptor(default defaultValue: Int) -> MHIntPreferenceDescriptor {
            .init(
                storageKey: storageKey,
                defaultSelection: defaultSelection,
                default: defaultValue
            )
        }
    }

    private struct StringRepresentableKey: MHStringPrefDescriptorRepresentable {
        let preferenceDescriptor: MHStringPreferenceDescriptor
    }

    private enum DemoRawStringValue: String {
        case first
        case second
    }

    private struct BoolHarness {
        @AppStorage private var value: Bool

        var wrappedValue: Bool {
            value
        }

        init(
            key: some MHBoolPrefDescriptorRepresentable,
            store: UserDefaults
        ) {
            _value = AppStorage(
                key,
                store: store
            )
        }

        init(
            key: some MHBoolPrefDescriptorRepresentable
        ) {
            _value = AppStorage(
                key
            )
        }
    }

    private struct IntHarness {
        @AppStorage private var value: Int

        var wrappedValue: Int {
            value
        }

        init(
            key: some MHIntPrefDescriptorRepresentable,
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
            key: some MHStringPrefDescriptorRepresentable,
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
            key: some MHStringPrefDescriptorRepresentable,
            store: UserDefaults
        ) {
            _value = AppStorage(
                key,
                store: store
            )
        }
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
            key: some MHStringPrefDescriptorRepresentable,
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
    func bool_bridge_supports_representable_keys() throws {
        let userDefaults = try makeUserDefaults(suiteName: "representable-bool")
        let key = BoolRepresentableKey(
            preferenceDescriptor: .init(
                storageKey: "representable-bool-key",
                defaultSelection: .standard,
                default: true
            )
        )
        let harness = BoolHarness(
            key: key,
            store: userDefaults
        )

        #expect(harness.wrappedValue)
    }

    @Test
    func bool_bridge_supports_default_selection_for_representable_keys() throws {
        let suiteName = "representable-selection-bool"
        let userDefaults = try makeUserDefaults(suiteName: suiteName)
        let key = BoolRepresentableKey(
            preferenceDescriptor: .init(
                storageKey: "representable-selection-bool-key",
                defaultSelection: .suite(
                    "  AppStorageRepresentableBridgeTests.\(suiteName)\n"
                ),
                default: false
            )
        )
        userDefaults.set(true, forKey: key.preferenceDescriptor.storageKey)
        let harness = BoolHarness(
            key: key
        )

        #expect(harness.wrappedValue)
    }

    @Test
    func int_bridge_supports_representable_keys() throws {
        let userDefaults = try makeUserDefaults(suiteName: "representable-int")
        let key = IntRepresentableKey(
            storageKey: "representable-int-key",
            defaultSelection: .standard
        )
        let harness = IntHarness(
            key: key,
            store: userDefaults
        )

        #expect(harness.wrappedValue == .zero)
    }

    @Test
    func string_bridge_supports_representable_keys() throws {
        let userDefaults = try makeUserDefaults(suiteName: "representable-string")
        let key = StringRepresentableKey(
            preferenceDescriptor: .init(
                storageKey: "representable-string-key",
                defaultSelection: .standard
            )
        )
        var harness = StringHarness(
            key: key,
            store: userDefaults
        )

        #expect(harness.wrappedValue == nil)

        harness.wrappedValue = "value"
        #expect(
            userDefaults.string(forKey: key.preferenceDescriptor.storageKey)
                == "value"
        )
    }

    @Test
    func required_string_bridge_supports_representable_keys() throws {
        let userDefaults = try makeUserDefaults(suiteName: "representable-required-string")
        let key = StringRepresentableKey(
            preferenceDescriptor: .init(
                storageKey: "representable-required-string-key",
                defaultSelection: .standard
            )
        )
        let harness = RequiredStringHarness(
            key: key,
            store: userDefaults
        )

        #expect(harness.wrappedValue.isEmpty)
    }

    @Test
    func raw_string_bridge_supports_representable_keys() throws {
        let userDefaults = try makeUserDefaults(suiteName: "representable-raw-string")
        let key = StringRepresentableKey(
            preferenceDescriptor: .init(
                storageKey: "representable-raw-string-key",
                defaultSelection: .standard
            )
        )
        userDefaults.set("second", forKey: key.preferenceDescriptor.storageKey)
        var harness = RawStringHarness(
            key: key,
            default: .first,
            store: userDefaults
        )

        #expect(harness.wrappedValue == .second)

        harness.wrappedValue = .first
        #expect(
            userDefaults.string(forKey: key.preferenceDescriptor.storageKey)
                == DemoRawStringValue.first.rawValue
        )
    }

    private func makeUserDefaults(suiteName: String) throws -> UserDefaults {
        let resolvedSuiteName = "AppStorageRepresentableBridgeTests.\(suiteName)"
        let userDefaults = try #require(
            UserDefaults(suiteName: resolvedSuiteName)
        )
        userDefaults.removePersistentDomain(forName: resolvedSuiteName)
        return userDefaults
    }
}
#endif
