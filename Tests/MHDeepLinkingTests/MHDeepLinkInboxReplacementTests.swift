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
}
