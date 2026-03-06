import Foundation
import MHDeepLinking
import Testing

struct MHDeepLinkingRouteHelpersTests {
    private enum ExampleRoute: Equatable, MHDeepLinkRoute {
        case root
        case item(String)

        var deepLinkDescriptor: MHDeepLinkDescriptor {
            switch self {
            case .root:
                return .init(pathComponents: [])
            case .item(let identifier):
                return .init(
                    pathComponents: ["item"],
                    queryItems: [
                        .init(name: "id", value: identifier)
                    ]
                )
            }
        }

        init?(deepLinkDescriptor: MHDeepLinkDescriptor) {
            switch deepLinkDescriptor.pathComponents {
            case []:
                self = .root
            case ["item"]:
                guard let identifier = deepLinkDescriptor.queryItems.first(where: { queryItem in
                    queryItem.name == "id"
                })?.value,
                    identifier.isEmpty == false else {
                    return nil
                }
                self = .item(identifier)
            default:
                return nil
            }
        }
    }

    private let configuration = MHDeepLinkConfiguration(
        customScheme: "mhplatform",
        preferredUniversalLinkHost: "example.com",
        allowedUniversalLinkHosts: ["example.com"],
        universalLinkPathPrefix: "MHPlatform",
        preferredTransport: .customScheme
    )

    @Test
    func store_route_helper_round_trips_and_consumes_once() throws {
        let suiteName = "MHDeepLinkRouteStoreHelperTests"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        userDefaults.removePersistentDomain(forName: suiteName)

        let store = MHDeepLinkStore(
            userDefaults: userDefaults,
            key: "pendingRoute"
        )
        let codec = MHDeepLinkCodec<ExampleRoute>(
            configuration: configuration
        )

        let storedURL = store.ingest(
            .item("rent"),
            using: codec
        )

        #expect(storedURL?.absoluteString == "mhplatform://item?id=rent")
        #expect(store.consumeLatest(using: codec) == .item("rent"))
        #expect(store.consumeLatest(using: codec) == nil)
    }

    @Test
    func store_route_helper_returns_nil_for_invalid_stored_url() throws {
        let suiteName = "MHDeepLinkRouteStoreInvalidTests"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        userDefaults.removePersistentDomain(forName: suiteName)

        let store = MHDeepLinkStore(
            userDefaults: userDefaults,
            key: "pendingRoute"
        )
        let codec = MHDeepLinkCodec<ExampleRoute>(
            configuration: configuration
        )
        let invalidURL = try #require(
            URL(string: "mhplatform://unknown?id=rent")
        )

        store.ingest(invalidURL)

        #expect(store.consumeLatest(using: codec) == nil)
        #expect(store.consumeLatest() == nil)
    }

    @Test
    func inbox_route_helper_round_trips_selected_transport() async {
        let inbox = MHDeepLinkInbox()
        let codec = MHDeepLinkCodec<ExampleRoute>(
            configuration: configuration
        )

        let storedURL = await inbox.ingest(
            .item("rent"),
            using: codec,
            transport: .universalLink
        )

        #expect(storedURL?.absoluteString == "https://example.com/MHPlatform/item?id=rent")
        let consumedRoute: ExampleRoute? = await inbox.consumeLatest(using: codec)
        #expect(consumedRoute == .item("rent"))
        let emptyRoute: ExampleRoute? = await inbox.consumeLatest(using: codec)
        #expect(emptyRoute == nil)
    }

    @Test
    func inbox_route_helper_returns_nil_for_invalid_pending_url() async throws {
        let inbox = MHDeepLinkInbox()
        let codec = MHDeepLinkCodec<ExampleRoute>(
            configuration: configuration
        )
        let invalidURL = try #require(
            URL(string: "https://invalid.example/MHPlatform/item?id=rent")
        )

        await inbox.ingest(invalidURL)

        let route: ExampleRoute? = await inbox.consumeLatest(using: codec)
        #expect(route == nil)
        #expect(await inbox.consumeLatest() == nil)
    }
}
