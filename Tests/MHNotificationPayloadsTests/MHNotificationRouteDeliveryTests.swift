#if canImport(UserNotifications)
import Foundation
import MHNotificationPayloads
import Testing

@MainActor
struct MHNotificationRouteDeliveryTests {
    @Test
    func deliverRouteURL_delivers_default_action_route() async {
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
            payload: payload,
            response: .init(
                actionIdentifier: "com.apple.UNNotificationDefaultActionIdentifier"
            ),
            deliver: deliver
        )

        #expect(outcome == .init(
            routeURL: url("mhplatform://item?id=rent"),
            source: .payload
        ))
        #expect(await recorder.values() == [url("mhplatform://item?id=rent")])
    }

    @Test
    func deliverRouteURL_delivers_custom_action_route() async {
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
            payload: payload,
            response: .init(
                actionIdentifier: "view-month"
            ),
            deliver: deliver
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
            payload: nil,
            response: .init(
                actionIdentifier: "unknown"
            ),
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
            payload: nil,
            response: .init(
                actionIdentifier: "view-month"
            ),
            deliver: deliver,
            fallbackRouteURL: legacyMonthFallbackRouteURL
        )

        let clearOutcome = await MHNotificationOrchestrator.deliverRouteURL(
            payload: nil,
            response: .init(
                actionIdentifier: "unknown"
            ),
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

    @Test
    func deliverRouteURL_fromUserInfo_uses_custom_codec_keys() async {
        let recorder = DeliveryRecorder()
        let deliver: @MainActor @Sendable (URL?) async -> Void = { routeURL in
            await recorder.record(routeURL)
        }
        let codec = MHNotificationPayloadCodec(
            configuration: .init(
                keys: .init(
                    defaultRouteURL: "primary",
                    fallbackRouteURL: "secondary",
                    actionRouteURLs: "actions"
                )
            )
        )
        let userInfo: [AnyHashable: Any] = [
            "actions": [
                "view-month": "mhplatform://month?year=2026&month=1"
            ]
        ]

        let outcome = MHNotificationOrchestrator.routeDeliveryOutcome(
            userInfo: userInfo,
            actionIdentifier: "view-month",
            codec: codec
        )
        let deliveredOutcome = await MHNotificationOrchestrator.deliverRouteURL(
            outcome,
            deliver: deliver
        )

        #expect(deliveredOutcome == .init(
            routeURL: url("mhplatform://month?year=2026&month=1"),
            source: .payload
        ))
        #expect(await recorder.values() == [url("mhplatform://month?year=2026&month=1")])
    }

    @Test
    func deliverRouteURL_fromUserInfo_uses_response_based_fallback() async {
        let recorder = DeliveryRecorder()
        let deliver: @MainActor @Sendable (URL?) async -> Void = { routeURL in
            await recorder.record(routeURL)
        }

        let outcome = MHNotificationOrchestrator.routeDeliveryOutcome(
            userInfo: [:],
            actionIdentifier: "browse",
        ) { _, response in
            guard response.actionIdentifier == "browse" else {
                return nil
            }

            return url("mhplatform://recipes")
        }
        let deliveredOutcome = await MHNotificationOrchestrator.deliverRouteURL(
            outcome,
            deliver: deliver
        )

        #expect(deliveredOutcome == .init(
            routeURL: url("mhplatform://recipes"),
            source: .fallback
        ))
        #expect(await recorder.values() == [url("mhplatform://recipes")])
    }

    @Test
    func deliverRouteURL_outcome_skips_delivery_when_no_route_and_clear_is_disabled() async {
        let recorder = DeliveryRecorder()
        let deliver: @MainActor @Sendable (URL?) async -> Void = { routeURL in
            await recorder.record(routeURL)
        }
        let outcome = MHNotificationRouteDeliveryOutcome(
            routeURL: nil,
            source: .noRoute
        )

        let deliveredOutcome = await MHNotificationOrchestrator.deliverRouteURL(
            outcome,
            deliver: deliver
        )

        #expect(deliveredOutcome == outcome)
        #expect(await recorder.values().isEmpty)
    }
}

private func url(_ value: String) -> URL {
    guard let parsedURL = URL(string: value) else {
        preconditionFailure("Invalid URL value: \(value)")
    }
    return parsedURL
}

private func legacyMonthFallbackRouteURL(
    _: MHNotificationPayload?,
    response: MHNotificationResponseContext
) -> URL? {
    guard response.actionIdentifier == "view-month" else {
        return nil
    }
    return url("mhplatform://month?year=2026&month=1")
}
#endif
