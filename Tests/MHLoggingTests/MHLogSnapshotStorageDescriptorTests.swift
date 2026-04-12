import Foundation
import MHLogging
import MHPreferences
import Testing

struct MHLogSnapshotStorageDescriptorTests {
    @Test
    func snapshot_storage_descriptor_can_participate_in_known_descriptor_cleanup() throws {
        let domainName = "MHLogSnapshotStorageDescriptorTests.\(UUID().uuidString)"
        let userDefaults = try #require(UserDefaults(suiteName: domainName))
        userDefaults.removePersistentDomain(forName: domainName)
        defer {
            userDefaults.removePersistentDomain(forName: domainName)
        }

        let currentKey = MHLogSnapshotStorageDescriptor(
            storageKey: "tests.logging.current",
            defaultSelection: .suite(domainName)
        )
        let previousKey = MHLogSnapshotStorageDescriptor(
            storageKey: "tests.logging.previous",
            defaultSelection: .suite(domainName)
        )
        userDefaults.set("current", forKey: currentKey.storageKey)
        userDefaults.set("previous", forKey: previousKey.storageKey)
        userDefaults.set("legacy", forKey: "tests.logging.legacy")

        let report = MHUserDefaultsCleanupService.removeUnknownKeys(
            from: userDefaults,
            domainName: domainName,
            knownDescriptors: [currentKey, previousKey]
        )

        #expect(report.didRun)
        #expect(report.removedStorageKeys == ["tests.logging.legacy"])
        #expect(userDefaults.object(forKey: currentKey.storageKey) != nil)
        #expect(userDefaults.object(forKey: previousKey.storageKey) != nil)
    }
}
