import Foundation
import MHDeepLinking
import Testing

struct MHDeepLinkInboxReplacementTests {
    @Test
    func inbox_replacePendingURL_clears_latest_value() async throws {
        let inbox = MHDeepLinkInbox()
        let url = try #require(URL(string: "mhplatform://item?id=replace"))

        await inbox.ingest(url)
        await inbox.replacePendingURL(nil)

        #expect(await inbox.consumeLatest() == nil)
    }

    @Test
    @MainActor
    func observable_inbox_replacePendingURL_updates_pending_state() async throws {
        let inbox = MHObservableDeepLinkInbox()
        let url = try #require(URL(string: "mhplatform://search?q=replace"))

        await inbox.replacePendingURL(url)
        #expect(inbox.pendingURL == url)

        await inbox.replacePendingURL(nil)
        #expect(inbox.pendingURL == nil)
        #expect(await inbox.consumeLatest() == nil)
    }

    @Test
    func store_replacePendingURL_updates_and_clears_latest_value() throws {
        let suiteName = "MHDeepLinkStoreReplacementTests"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        userDefaults.removePersistentDomain(forName: suiteName)

        let store = MHDeepLinkStore(
            userDefaults: userDefaults,
            key: "pendingURL"
        )
        let firstURL = try #require(URL(string: "mhplatform://item?id=first"))
        let secondURL = try #require(URL(string: "mhplatform://item?id=second"))

        store.replacePendingURL(firstURL)
        store.replacePendingURL(secondURL)

        #expect(store.consumeLatest() == secondURL)

        store.replacePendingURL(firstURL)
        store.clear()

        #expect(store.consumeLatest() == nil)
    }

    @Test
    @MainActor
    func destinations_support_setPendingURL_protocol() async throws {
        let inbox = MHDeepLinkInbox()
        let observableInbox = MHObservableDeepLinkInbox()
        let suiteName = "MHDeepLinkURLDestinationTests"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        userDefaults.removePersistentDomain(forName: suiteName)
        let store = MHDeepLinkStore(
            userDefaults: userDefaults,
            key: "pendingURL"
        )
        let url = try #require(URL(string: "mhplatform://settings"))

        await verifyDestinationRoundTrip(
            destination: inbox,
            source: inbox,
            url: url
        )
        await verifyDestinationRoundTrip(
            destination: observableInbox,
            source: observableInbox,
            url: url
        )
        await verifyDestinationRoundTrip(
            destination: store,
            source: store,
            url: url
        )
    }
}

private extension MHDeepLinkInboxReplacementTests {
    func verifyDestinationRoundTrip<Destination: MHDeepLinkURLDestination & MHDeepLinkURLSource>(
        destination: Destination,
        source: Destination,
        url: URL
    ) async {
        await destination.setPendingURL(url)
        #expect(await source.consumeLatestURL() == url)

        await destination.setPendingURL(nil)
        #expect(await source.consumeLatestURL() == nil)
    }
}
