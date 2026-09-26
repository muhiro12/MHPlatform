#if canImport(SwiftUI)
import Foundation
import MHPreferences
import MHPreferencesUI
import SwiftUI
import Testing

struct AppStorageShorthandTests {
    private struct Harness {
        @AppStorage(.debugEnabled)
        var isDebugEnabled
        @AppStorage(.launchCount)
        var launchCount
        @AppStorage(.displayName, default: "Guest")
        var displayName

        init(store: UserDefaults) {
            _isDebugEnabled = AppStorage(.debugEnabled, store: store)
            _launchCount = AppStorage(.launchCount, store: store)
            _displayName = AppStorage(.displayName, default: "Guest", store: store)
        }
    }

    @Test
    func enum_shorthand_infers_types_and_respects_explicit_store() throws {
        let suiteName = "tests.app-storage.shorthand.\(UUID())"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }
        let harness = Harness(store: userDefaults)

        #expect(harness.isDebugEnabled == false)
        #expect(harness.launchCount == .zero)
        #expect(harness.displayName == "Guest")

        harness.isDebugEnabled = true
        harness.launchCount = 3
        harness.displayName = "Avery"

        #expect(userDefaults.bool(forKey: "debug-enabled"))
        #expect(userDefaults.integer(forKey: "launch-count") == 3)
        #expect(userDefaults.string(forKey: "display-name") == "Avery")
    }
}

extension AppStorageShorthandTests {
    enum ShorthandBoolPreference: MHBoolPrefDescriptorRepresentable {
        case debugEnabled

        var preferenceDescriptor: MHBoolPreferenceDescriptor {
            .init(
                storageKey: "debug-enabled",
                defaultSelection: .suite("tests.app-storage.shorthand.defaults")
            )
        }
    }

    enum ShorthandIntPreference: MHIntPrefDescriptorRepresentable {
        case launchCount

        func preferenceDescriptor(default defaultValue: Int) -> MHIntPreferenceDescriptor {
            .init(
                storageKey: "launch-count",
                defaultSelection: .suite("tests.app-storage.shorthand.defaults"),
                default: defaultValue
            )
        }
    }

    enum ShorthandStringPreference: MHStringPrefDescriptorRepresentable {
        case displayName

        var preferenceDescriptor: MHStringPreferenceDescriptor {
            .init(
                storageKey: "display-name",
                defaultSelection: .suite("tests.app-storage.shorthand.defaults")
            )
        }
    }
}

private extension MHBoolPreferenceDescriptor {
    static var debugEnabled: Self {
        AppStorageShorthandTests.ShorthandBoolPreference.debugEnabled.preferenceDescriptor
    }
}

private extension MHIntPreferenceDescriptor {
    static var launchCount: Self {
        AppStorageShorthandTests.ShorthandIntPreference.launchCount.preferenceDescriptor(default: .zero)
    }
}

private extension MHStringPreferenceDescriptor {
    static var displayName: Self {
        AppStorageShorthandTests.ShorthandStringPreference.displayName.preferenceDescriptor
    }
}
#endif
