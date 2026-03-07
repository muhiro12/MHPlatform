#if canImport(SwiftUI)
import Foundation
import MHPreferences
import SwiftUI
import Testing

struct AppStorageRepresentableBridgeTests {
    private struct BoolRepresentableKey: MHBoolPreferenceKeyRepresentable {
        let preferenceKey: MHBoolPreferenceKey
    }

    private struct IntRepresentableKey: MHIntPreferenceKeyRepresentable {
        let storageKey: String

        func preferenceKey(default defaultValue: Int) -> MHIntPreferenceKey {
            .init(
                storageKey: storageKey,
                default: defaultValue
            )
        }
    }

    private struct StringRepresentableKey: MHStringPreferenceKeyRepresentable {
        let preferenceKey: MHStringPreferenceKey
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
            key: some MHBoolPreferenceKeyRepresentable,
            store: UserDefaults
        ) {
            _value = AppStorage(
                key,
                store: store
            )
        }
    }

    private struct IntHarness {
        @AppStorage private var value: Int

        var wrappedValue: Int {
            value
        }

        init(
            key: some MHIntPreferenceKeyRepresentable,
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
            key: some MHStringPreferenceKeyRepresentable,
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
            key: some MHStringPreferenceKeyRepresentable,
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
            key: some MHStringPreferenceKeyRepresentable,
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
            preferenceKey: .init(
                storageKey: "representable-bool-key",
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
    func int_bridge_supports_representable_keys() throws {
        let userDefaults = try makeUserDefaults(suiteName: "representable-int")
        let key = IntRepresentableKey(storageKey: "representable-int-key")
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
            preferenceKey: .init(storageKey: "representable-string-key")
        )
        var harness = StringHarness(
            key: key,
            store: userDefaults
        )

        #expect(harness.wrappedValue == nil)

        harness.wrappedValue = "value"
        #expect(userDefaults.string(forKey: key.preferenceKey.storageKey) == "value")
    }

    @Test
    func required_string_bridge_supports_representable_keys() throws {
        let userDefaults = try makeUserDefaults(suiteName: "representable-required-string")
        let key = StringRepresentableKey(
            preferenceKey: .init(storageKey: "representable-required-string-key")
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
            preferenceKey: .init(storageKey: "representable-raw-string-key")
        )
        userDefaults.set("second", forKey: key.preferenceKey.storageKey)
        var harness = RawStringHarness(
            key: key,
            default: .first,
            store: userDefaults
        )

        #expect(harness.wrappedValue == .second)

        harness.wrappedValue = .first
        #expect(
            userDefaults.string(forKey: key.preferenceKey.storageKey)
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
