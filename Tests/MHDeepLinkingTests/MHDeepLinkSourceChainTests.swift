import Foundation
@testable import MHDeepLinking
import Testing

struct MHDeepLinkSourceChainTests {
    @Test
    func variadic_initializer_consumes_first_available_source_only() async throws {
        let first = MHDeepLinkInbox()
        let second = MHDeepLinkInbox()
        let third = MHDeepLinkInbox()
        let secondURL = try #require(URL(string: "test://second"))
        let thirdURL = try #require(URL(string: "test://third"))

        await second.ingest(secondURL)
        await third.ingest(thirdURL)

        let chain = MHDeepLinkSourceChain(
            first,
            second,
            third
        )

        let resolvedURL = await chain.consumeLatestURL()

        #expect(resolvedURL == secondURL)
        #expect(await first.consumeLatest() == nil)
        #expect(await second.consumeLatest() == nil)
        #expect(await third.consumeLatest() == thirdURL)
    }

    @Test
    func array_initializer_consumes_from_later_source_when_prefix_is_empty() async throws {
        let first = MHDeepLinkInbox()
        let suiteName = "MHDeepLinkSourceChainTests.\(UUID().uuidString)"
        let url = try #require(URL(string: "test://store"))
        guard let userDefaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Failed to create UserDefaults suite for source-chain tests.")
            return
        }
        userDefaults.removePersistentDomain(forName: suiteName)
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }
        let second = MHDeepLinkStore(
            userDefaults: userDefaults,
            key: "pendingURL"
        )
        let sources: [any MHDeepLinkURLSource] = [
            first,
            second
        ]

        second.ingest(url)

        let chain = MHDeepLinkSourceChain(sources)

        #expect(await chain.consumeLatestURL() == url)
        #expect(await first.consumeLatest() == nil)
        #expect(second.consumeLatest() == nil)
    }

    @Test
    func forwardLatestURL_stores_first_available_value_in_destination() async throws {
        let source = MHDeepLinkInbox()
        let destination = MHDeepLinkInbox()
        let url = try #require(URL(string: "test://forwarded"))

        await source.ingest(url)

        let chain = MHDeepLinkSourceChain(source)
        let forwardedURL = await chain.forwardLatestURL(to: destination)

        #expect(forwardedURL == url)
        #expect(await destination.consumeLatest() == url)
        #expect(await source.consumeLatest() == nil)
    }

    @Test
    func forwardLatestURL_leaves_destination_unchanged_when_no_source_has_value() async throws {
        let destination = MHDeepLinkInbox()
        let existingURL = try #require(URL(string: "test://existing"))
        let chain = MHDeepLinkSourceChain()

        await destination.ingest(existingURL)

        let forwardedURL = await chain.forwardLatestURL(to: destination)

        #expect(forwardedURL == nil)
        #expect(await destination.consumeLatest() == existingURL)
    }
}
