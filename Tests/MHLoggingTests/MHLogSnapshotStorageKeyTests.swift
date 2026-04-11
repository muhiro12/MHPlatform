import Foundation
import MHLogging
import MHPreferences
import Testing

struct MHLogSnapshotStorageKeyTests {
    @Test
    func snapshot_storage_key_can_participate_in_known_key_cleanup() throws {
        let domainName = "MHLogSnapshotStorageKeyTests.\(UUID().uuidString)"
        let userDefaults = try #require(UserDefaults(suiteName: domainName))
        userDefaults.removePersistentDomain(forName: domainName)
        defer {
            userDefaults.removePersistentDomain(forName: domainName)
        }

        let currentKey = MHLogSnapshotStorageKey(
            storageKey: "tests.logging.current"
        )
        let previousKey = MHLogSnapshotStorageKey(
            storageKey: "tests.logging.previous"
        )
        userDefaults.set("current", forKey: currentKey.storageKey)
        userDefaults.set("previous", forKey: previousKey.storageKey)
        userDefaults.set("legacy", forKey: "tests.logging.legacy")

        let report = MHUserDefaultsCleanupService.removeUnknownKeys(
            from: userDefaults,
            domainName: domainName,
            knownKeys: [currentKey, previousKey]
        )

        #expect(report.didRun)
        #expect(report.removedStorageKeys == ["tests.logging.legacy"])
        #expect(userDefaults.object(forKey: currentKey.storageKey) != nil)
        #expect(userDefaults.object(forKey: previousKey.storageKey) != nil)
    }
}
