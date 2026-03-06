import Foundation
import MHNotificationPayloads
import Testing

struct MHNotificationPayloadCodecTests {
    @Test
    func encode_decode_round_trip_with_routes_and_metadata() throws {
        let codec = MHNotificationPayloadCodec(
            configuration: .init(
                decodableMetadataKeys: [
                    "itemIdentifier",
                    "notificationKind"
                ]
            )
        )
        let payload = MHNotificationPayload(
            routes: .init(
                defaultRouteURL: url("mhplatform://item?id=rent"),
                fallbackRouteURL: url("mhplatform://month?year=2026&month=1"),
                actionRouteURLs: [
                    "view-month": url("mhplatform://month?year=2026&month=1")
                ]
            ),
            metadata: [
                "itemIdentifier": "rent",
                "notificationKind": "upcoming-payment"
            ]
        )

        let encoded = codec.encode(payload)
        let decoded = try #require(codec.decode(encoded))

        #expect(decoded == payload)
    }

    @Test
    func decode_ignores_invalid_url_entries() throws {
        let codec = MHNotificationPayloadCodec()
        let userInfo: [AnyHashable: Any] = [
            "mh.notification.defaultRouteURL": "mhplatform://root",
            "mh.notification.fallbackRouteURL": "",
            "mh.notification.actionRouteURLs": [
                "view-item": "mhplatform://item?id=rent",
                "view-month": ""
            ]
        ]

        let decoded = try #require(codec.decode(userInfo))

        #expect(decoded.routes.defaultRouteURL == url("mhplatform://root"))
        #expect(decoded.routes.fallbackRouteURL == nil)
        #expect(decoded.routes.actionRouteURLs == [
            "view-item": url("mhplatform://item?id=rent")
        ])
    }

    @Test
    func decode_returns_nil_when_no_valid_routes_exist() {
        let codec = MHNotificationPayloadCodec(
            configuration: .init(
                decodableMetadataKeys: ["contentKind"]
            )
        )
        let userInfo: [AnyHashable: Any] = [
            "mh.notification.defaultRouteURL": "",
            "mh.notification.fallbackRouteURL": "",
            "mh.notification.actionRouteURLs": [
                "browse": ""
            ],
            "contentKind": "recipeSuggestion"
        ]

        #expect(codec.decode(userInfo) == nil)
    }

    @Test
    func decode_filters_metadata_by_allowlist_and_reserved_keys() throws {
        let codec = MHNotificationPayloadCodec(
            configuration: .init(
                keys: .mhPlatform,
                decodableMetadataKeys: [
                    "contentKind",
                    "stableIdentifier",
                    "mh.notification.defaultRouteURL"
                ]
            )
        )
        let userInfo: [AnyHashable: Any] = [
            "mh.notification.defaultRouteURL": "mhplatform://recipes",
            "contentKind": "recipeSuggestion",
            "stableIdentifier": "recipe-123",
            "other": "ignored"
        ]

        let decoded = try #require(codec.decode(userInfo))

        #expect(decoded.metadata == [
            "contentKind": "recipeSuggestion",
            "stableIdentifier": "recipe-123"
        ])
    }

    @Test
    func custom_key_configuration_decodes_incomes_user_info() throws {
        let codec = MHNotificationPayloadCodec(
            configuration: .init(
                keys: .init(
                    defaultRouteURL: "primaryDeepLinkURL",
                    fallbackRouteURL: "secondaryDeepLinkURL",
                    actionRouteURLs: "actionRouteURLs"
                )
            )
        )
        let userInfo: [AnyHashable: Any] = [
            "primaryDeepLinkURL": "incomes://item?id=rent",
            "secondaryDeepLinkURL": "incomes://month?year=2026&month=1"
        ]

        let decoded = try #require(codec.decode(userInfo))

        #expect(
            decoded.routes == .init(
                defaultRouteURL: url("incomes://item?id=rent"),
                fallbackRouteURL: url("incomes://month?year=2026&month=1")
            )
        )
    }

    @Test
    func custom_key_configuration_decodes_cookle_user_info() throws {
        let codec = MHNotificationPayloadCodec(
            configuration: .init(
                keys: .init(
                    defaultRouteURL: "routeURL",
                    fallbackRouteURL: "fallbackRouteURL",
                    actionRouteURLs: "actionRouteURLs"
                ),
                decodableMetadataKeys: [
                    "contentKind",
                    "stableIdentifier"
                ]
            )
        )
        let userInfo: [AnyHashable: Any] = [
            "routeURL": "cookle://recipe?id=abc",
            "contentKind": "recipeSuggestion",
            "stableIdentifier": "abc"
        ]

        let decoded = try #require(codec.decode(userInfo))

        #expect(decoded.routes.defaultRouteURL == url("cookle://recipe?id=abc"))
        #expect(decoded.metadata == [
            "contentKind": "recipeSuggestion",
            "stableIdentifier": "abc"
        ])
    }

    @Test
    func encode_drops_metadata_entries_that_collide_with_reserved_keys() {
        let codec = MHNotificationPayloadCodec()
        let payload = MHNotificationPayload(
            routes: .init(
                defaultRouteURL: url("mhplatform://item?id=rent"),
                fallbackRouteURL: url("mhplatform://month?year=2026&month=1")
            ),
            metadata: [
                "mh.notification.defaultRouteURL": "mhplatform://override",
                "mh.notification.fallbackRouteURL": "mhplatform://override-fallback",
                "note": "kept"
            ]
        )

        let encoded = codec.encode(payload)

        #expect(
            encoded["mh.notification.defaultRouteURL"] as? String ==
                "mhplatform://item?id=rent"
        )
        #expect(
            encoded["mh.notification.fallbackRouteURL"] as? String ==
                "mhplatform://month?year=2026&month=1"
        )
        #expect(encoded["note"] as? String == "kept")
    }

    private func url(_ value: String) -> URL {
        guard let parsedURL = URL(string: value) else {
            preconditionFailure("Invalid URL value: \(value)")
        }
        return parsedURL
    }
}
