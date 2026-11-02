import Foundation
import MHDeepLinking
import Testing

struct StrictWebLinkTests {
    private struct Route: MHDeepLinkRoute {
        let deepLinkDescriptor: MHDeepLinkDescriptor
    }

    private let codec = MHDeepLinkCodec<Route>(configuration: .init(
        customScheme: "journal",
        preferredUniversalLinkHost: "example.org",
        allowedUniversalLinkHosts: ["example.org"],
        universalLinkPathPrefix: "Journal",
        preferredTransport: .universalLink,
        webLinkPolicy: .strict
    ))

    @Test(arguments: [
        "http://example.org/Journal/item",
        "https://elsewhere.org/Journal/item",
        "https://example.org/item",
        "https://example.org/Other/item",
        "https://example.org/JournalExtra/item",
        "https://example.org/journal/item",
        "https://user:password@example.org/Journal/item",
        "https://example.org:443/Journal/item",
        "https://example.org:/Journal/item",
        "https://example.org:99999999999999999999999/Journal/item",
        "https://example.org//Journal/item",
        "https://example.org/Journal/../Other/item",
        "https://example.org/Journal%2Fitem"
    ])
    func rejectsLinksOutsideBoundary(_ string: String) throws {
        #expect(codec.parse(try #require(URL(string: string))) == nil)
    }

    @Test
    func neverSharesAPathThatWouldIdentifyADifferentResource() {
        let route = Route(deepLinkDescriptor: .init(pathComponents: ["item", "a/b"]))
        #expect(codec.url(for: route, transport: .universalLink) == nil)
        #expect(codec.preferredURL(for: route) == nil)
    }

    @Test
    func unlistedSharingHostFallsBackToTheConfiguredScheme() throws {
        let fallbackCodec = MHDeepLinkCodec<Route>(configuration: .init(
            customScheme: "journal",
            preferredUniversalLinkHost: "other.example.org",
            allowedUniversalLinkHosts: ["example.org"],
            universalLinkPathPrefix: "Journal",
            preferredTransport: .universalLink,
            webLinkPolicy: .strict
        ))
        let route = Route(deepLinkDescriptor: .init(pathComponents: ["item", "abc"]))
        #expect(fallbackCodec.url(for: route, transport: .universalLink) == nil)
        let url = try #require(fallbackCodec.preferredURL(for: route))
        #expect(url.absoluteString == "journal://item/abc")
        #expect(fallbackCodec.parse(url)?.deepLinkDescriptor == route.deepLinkDescriptor)
    }

    @Test
    func routesKeepPathAndQueryGrammarInBothTransports() throws {
        for descriptor in [
            MHDeepLinkDescriptor(pathComponents: ["item", "abc"]),
            .init(pathComponents: ["item"], queryItems: [.init(name: "id", value: "abc")])
        ] {
            let route = Route(deepLinkDescriptor: descriptor)
            for transport in [MHDeepLinkTransport.customScheme, .universalLink] {
                let url = try #require(codec.url(for: route, transport: transport))
                #expect(codec.parse(url)?.deepLinkDescriptor == descriptor)
            }
        }
        let upperHost = try #require(URL(string: "https://EXAMPLE.ORG/Journal/item"))
        #expect(codec.parse(upperHost)?.deepLinkDescriptor.pathComponents == ["item"])
    }
}
