#if canImport(UserNotifications)
import Foundation
import MHNotificationPayloads
import Testing

@MainActor
struct MHNotificationRouteDeliveryTests {
    @Test
    func deliverRouteURL_delivers_default_action_route() async {
        let codec = MHNotificationPayloadCodec()
        let payload = MHNotificationPayload(
            routes: .init(
                defaultRouteURL: url("mhplatform://item?id=rent")
            )
        )
        let recorder = DeliveryRecorder()
        let deliver: @MainActor @Sendable (URL?) async -> Void = { routeURL in
            await recorder.record(routeURL)
        }

        let outcome = await MHNotificationOrchestrator.deliverRouteURL(
            userInfo: codec.encode(payload),
            actionIdentifier: "com.apple.UNNotificationDefaultActionIdentifier",
            deliver: deliver,
            codec: codec
        )

        #expect(outcome == .init(
            routeURL: url("mhplatform://item?id=rent"),
            source: .payload
        ))
        #expect(await recorder.values() == [url("mhplatform://item?id=rent")])
    }

    @Test
    func deliverRouteURL_delivers_custom_action_route() async {
        let codec = MHNotificationPayloadCodec()
        let payload = MHNotificationPayload(
            routes: .init(
                defaultRouteURL: url("mhplatform://item?id=rent"),
                actionRouteURLs: [
                    "view-month": url("mhplatform://month?year=2026&month=1")
                ]
            )
        )
        let recorder = DeliveryRecorder()
        let deliver: @MainActor @Sendable (URL?) async -> Void = { routeURL in
            await recorder.record(routeURL)
        }

        let outcome = await MHNotificationOrchestrator.deliverRouteURL(
            userInfo: codec.encode(payload),
            actionIdentifier: "view-month",
            deliver: deliver,
            codec: codec
        )

        #expect(outcome == .init(
            routeURL: url("mhplatform://month?year=2026&month=1"),
            source: .payload
        ))
        #expect(await recorder.values() == [url("mhplatform://month?year=2026&month=1")])
    }

    @Test
    func deliverRouteURL_returns_no_route_without_delivery_when_missing() async {
        let recorder = DeliveryRecorder()
        let deliver: @MainActor @Sendable (URL?) async -> Void = { routeURL in
            await recorder.record(routeURL)
        }

        let outcome = await MHNotificationOrchestrator.deliverRouteURL(
            userInfo: [:],
            actionIdentifier: "unknown",
            deliver: deliver
        )

        #expect(outcome == .init(
            routeURL: nil,
            source: .noRoute
        ))
        #expect(await recorder.values().isEmpty)
    }

    @Test
    func deliverRouteURL_applies_fallback_and_can_clear_pending_route() async {
        let recorder = DeliveryRecorder()
        let legacyURL = url("mhplatform://month?year=2026&month=1")
        let deliver: @MainActor @Sendable (URL?) async -> Void = { routeURL in
            await recorder.record(routeURL)
        }

        let fallbackOutcome = await MHNotificationOrchestrator.deliverRouteURL(
            userInfo: [
                "secondaryDeepLinkURL": legacyURL.absoluteString
            ],
            actionIdentifier: "view-month",
            deliver: deliver,
            fallbackRouteURL: legacyMonthFallbackRouteURL
        )

        let clearOutcome = await MHNotificationOrchestrator.deliverRouteURL(
            userInfo: [:],
            actionIdentifier: "unknown",
            deliver: deliver,
            clearPendingURLWhenNoRoute: true
        )

        #expect(fallbackOutcome == .init(
            routeURL: legacyURL,
            source: .fallback
        ))
        #expect(clearOutcome == .init(
            routeURL: nil,
            source: .noRoute
        ))
        #expect(await recorder.values() == [legacyURL, nil])
    }
}

private func url(_ value: String) -> URL {
    guard let parsedURL = URL(string: value) else {
        preconditionFailure("Invalid URL value: \(value)")
    }
    return parsedURL
}

private func legacyMonthFallbackRouteURL(
    userInfo: [AnyHashable: Any],
    actionIdentifier: String
) -> URL? {
    guard actionIdentifier == "view-month" else {
        return nil
    }
    return URL(string: userInfo["secondaryDeepLinkURL"] as? String ?? "")
}
#endif
