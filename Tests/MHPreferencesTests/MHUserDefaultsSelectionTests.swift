import Foundation
import MHPreferences
import Testing

struct MHUserDefaultsSelectionTests {
    private enum Constants {
        static let storageKey = "tests.user-defaults-selection.flag"
    }

    @Test
    func standard_selection_resolves_standard_defaults() {
        let resolvedUserDefaults = MHUserDefaultsSelection.standard.resolveUserDefaults()

        #expect(resolvedUserDefaults === UserDefaults.standard)
    }

    @Test
    func suite_selection_resolves_requested_suite() throws {
        let suiteName = "MHUserDefaultsSelectionTests.\(UUID().uuidString)"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        userDefaults.removePersistentDomain(forName: suiteName)
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }

        let resolvedUserDefaults = MHUserDefaultsSelection
            .suite(suiteName)
            .resolveUserDefaults()

        resolvedUserDefaults.set(true, forKey: Constants.storageKey)

        #expect(userDefaults.bool(forKey: Constants.storageKey))
    }

    @Test
    func suite_selection_trims_whitespace() throws {
        let suiteName = "MHUserDefaultsSelectionTests.trim.\(UUID().uuidString)"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        userDefaults.removePersistentDomain(forName: suiteName)
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }

        let resolvedUserDefaults = MHUserDefaultsSelection
            .suite("  \(suiteName)\n")
            .resolveUserDefaults()

        resolvedUserDefaults.set("kept", forKey: Constants.storageKey)

        #expect(userDefaults.string(forKey: Constants.storageKey) == "kept")
    }

    @Test
    func invalid_suite_selection_returns_nil() {
        let resolvedUserDefaults = MHUserDefaultsSelection
            .suite("  \n")
            .makeUserDefaults()

        #expect(resolvedUserDefaults == nil)
    }
}
