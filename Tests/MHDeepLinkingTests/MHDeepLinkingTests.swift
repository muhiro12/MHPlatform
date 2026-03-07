import Foundation
import MHDeepLinking
import Testing

struct MHDeepLinkingTests {
    private enum ExampleRoute: Equatable, MHDeepLinkRoute {
        case root
        case item(String)
        case search(String?)

        var deepLinkDescriptor: MHDeepLinkDescriptor {
            switch self {
            case .root:
                return MHDeepLinkDescriptor(pathComponents: [])
            case .item(let identifier):
                return MHDeepLinkDescriptor(
                    pathComponents: ["item"],
                    queryItems: [
                        .init(name: "id", value: identifier)
                    ]
                )
            case .search(let query):
                let queryItems: [URLQueryItem]
                if let query {
                    queryItems = [
                        .init(name: "q", value: query)
                    ]
                } else {
                    queryItems = []
                }
                return MHDeepLinkDescriptor(
                    pathComponents: ["search"],
                    queryItems: queryItems
                )
            }
        }

        init?(deepLinkDescriptor: MHDeepLinkDescriptor) {
            switch deepLinkDescriptor.pathComponents {
            case []:
                self = .root
            case ["item"]:
                let identifierQueryItem = deepLinkDescriptor.queryItems.first { queryItem in
                    queryItem.name == "id"
                }
                guard let identifier = identifierQueryItem?.value,
                      identifier.isEmpty == false else {
                    return nil
                }
                self = .item(identifier)
            case ["search"]:
                let query = deepLinkDescriptor.queryItems.first { queryItem in
                    queryItem.name == "q"
                }?.value
                self = .search(query)
            default:
                return nil
            }
        }
    }

    private struct DescriptorRoute: MHDeepLinkRoute {
        let deepLinkDescriptor: MHDeepLinkDescriptor

        init?(deepLinkDescriptor: MHDeepLinkDescriptor) {
            self.deepLinkDescriptor = deepLinkDescriptor
        }
    }

    private let configuration = MHDeepLinkConfiguration(
        customScheme: "mhplatform",
        preferredUniversalLinkHost: "example.com",
        allowedUniversalLinkHosts: [
            "example.com",
            "www.example.com"
        ],
        universalLinkPathPrefix: "MHPlatform",
        preferredTransport: .customScheme
    )

    @Test
    func build_custom_scheme_url() {
        let codec = MHDeepLinkCodec<ExampleRoute>(
            configuration: configuration
        )

        let url = codec.url(
            for: .item("rent"),
            transport: .customScheme
        )

        #expect(url?.absoluteString == "mhplatform://item?id=rent")
    }

    @Test
    func build_universal_link_url() {
        let codec = MHDeepLinkCodec<ExampleRoute>(
            configuration: configuration
        )

        let url = codec.url(
            for: .search("tea"),
            transport: .universalLink
        )

        #expect(url?.absoluteString == "https://example.com/MHPlatform/search?q=tea")
    }

    @Test
    func parse_strips_path_prefix_case_insensitively() throws {
        let codec = MHDeepLinkCodec<ExampleRoute>(
            configuration: configuration
        )

        let route = codec.parse(
            try #require(URL(string: "https://www.example.com/mhplatform/search?q=tea"))
        )

        #expect(route == .search("tea"))
    }

    @Test
    func parse_rejects_unknown_universal_link_host() throws {
        let codec = MHDeepLinkCodec<ExampleRoute>(
            configuration: configuration
        )

        let route = codec.parse(
            try #require(URL(string: "https://invalid.example/MHPlatform/item?id=rent"))
        )

        #expect(route == nil)
    }

    @Test
    func parse_uses_route_for_empty_destination() throws {
        let codec = MHDeepLinkCodec<ExampleRoute>(
            configuration: configuration
        )

        let customSchemeRoute = codec.parse(
            try #require(URL(string: "mhplatform://"))
        )
        let universalLinkRoute = codec.parse(
            try #require(URL(string: "https://example.com/MHPlatform"))
        )

        #expect(customSchemeRoute == .root)
        #expect(universalLinkRoute == .root)
    }

    @Test
    func preserves_query_item_order_for_round_trip() throws {
        let codec = MHDeepLinkCodec<DescriptorRoute>(
            configuration: configuration
        )

        let route = try #require(
            DescriptorRoute(
                deepLinkDescriptor: MHDeepLinkDescriptor(
                    pathComponents: ["filters"],
                    queryItems: [
                        .init(name: "tag", value: "rent"),
                        .init(name: "tag", value: "urgent"),
                        .init(name: "sort", value: "amount")
                    ]
                )
            )
        )

        let builtURL = try #require(
            codec.url(
                for: route,
                transport: .customScheme
            )
        )
        let parsedRoute = try #require(codec.parse(builtURL))

        #expect(parsedRoute.deepLinkDescriptor == route.deepLinkDescriptor)
    }

    @Test
    func preferred_url_falls_back_to_universal_link() {
        let codec = MHDeepLinkCodec<ExampleRoute>(
            configuration: MHDeepLinkConfiguration(
                customScheme: "",
                preferredUniversalLinkHost: "example.com",
                allowedUniversalLinkHosts: ["example.com"],
                universalLinkPathPrefix: "MHPlatform",
                preferredTransport: .customScheme
            )
        )

        let url = codec.preferredURL(for: .item("rent"))

        #expect(url?.absoluteString == "https://example.com/MHPlatform/item?id=rent")
    }

    @Test
    func store_consumes_value_once() throws {
        let suiteName = "MHDeepLinkStoreTests"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        userDefaults.removePersistentDomain(forName: suiteName)

        let store = MHDeepLinkStore(
            userDefaults: userDefaults,
            key: "pendingURL"
        )
        let url = try #require(URL(string: "mhplatform://item?id=rent"))

        store.ingest(url)

        #expect(store.consumeLatest() == url)
        #expect(store.consumeLatest() == nil)
    }

    @Test
    func suite_store_consumes_value_once() throws {
        let suiteName = "MHDeepLinkStoreTests.suite"
        let store = try #require(
            MHDeepLinkStore(
                suiteName: suiteName,
                key: "pendingURL"
            )
        )
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        let url = try #require(URL(string: "mhplatform://item?id=suite"))

        userDefaults.removePersistentDomain(forName: suiteName)
        store.ingest(url)

        #expect(store.consumeLatest() == url)
        #expect(store.consumeLatest() == nil)
    }

    @Test
    func inbox_consumes_value_once() async throws {
        let inbox = MHDeepLinkInbox()
        let url = try #require(URL(string: "mhplatform://search?q=tea"))

        await inbox.ingest(url)

        let firstConsume = await inbox.consumeLatest()
        let secondConsume = await inbox.consumeLatest()

        #expect(firstConsume == url)
        #expect(secondConsume == nil)
    }

    @Test
    @MainActor
    func observable_inbox_tracks_latest_pending_url() async throws {
        let inbox = MHObservableDeepLinkInbox()
        let firstURL = try #require(URL(string: "mhplatform://item?id=first"))
        let secondURL = try #require(URL(string: "mhplatform://item?id=second"))

        await inbox.ingest(firstURL)
        #expect(inbox.pendingURL == firstURL)

        await inbox.ingest(secondURL)
        #expect(inbox.pendingURL == secondURL)

        let consumedURL = await inbox.consumeLatest()
        let consumedAgain = await inbox.consumeLatest()

        #expect(consumedURL == secondURL)
        #expect(consumedAgain == nil)
        #expect(inbox.pendingURL == nil)
    }

    @Test
    @MainActor
    func observable_inbox_clear_resets_pending_url() async throws {
        let inbox = MHObservableDeepLinkInbox()
        let url = try #require(URL(string: "mhplatform://search?q=clear"))

        await inbox.ingest(url)
        #expect(inbox.pendingURL == url)

        await inbox.clear()

        #expect(inbox.pendingURL == nil)
        #expect(await inbox.consumeLatest() == nil)
    }
}
