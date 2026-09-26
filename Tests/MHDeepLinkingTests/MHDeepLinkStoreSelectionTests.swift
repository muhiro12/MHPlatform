import Foundation
import MHDeepLinking
import MHPreferences
import Testing

struct MHDeepLinkStoreSelectionTests {
    @Test
    func selection_shares_pending_url_only_with_the_selected_suite() throws {
        let suiteName = "tests.deep-link.selection.\(UUID())"
        let otherSuiteName = "tests.deep-link.other.\(UUID())"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        let otherDefaults = try #require(UserDefaults(suiteName: otherSuiteName))
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
            otherDefaults.removePersistentDomain(forName: otherSuiteName)
        }
        let descriptor = MHRawStorageDescriptor(
            storageKey: "pending-url",
            defaultSelection: .suite(suiteName)
        )
        let writer = MHDeepLinkStore(selection: .suite(suiteName), key: descriptor.storageKey)
        let reader = MHDeepLinkStore(key: descriptor)
        let otherStore = MHDeepLinkStore(
            selection: .suite(otherSuiteName),
            key: descriptor.storageKey
        )
        let url = try #require(URL(string: "mhplatform://settings"))

        writer.ingest(url)

        #expect(otherStore.consumeLatest() == nil)
        #expect(reader.consumeLatest() == url)
        #expect(writer.consumeLatest() == nil)
        #expect(userDefaults.object(forKey: descriptor.storageKey) == nil)
    }
}
