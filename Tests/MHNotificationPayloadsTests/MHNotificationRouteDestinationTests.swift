#if canImport(UserNotifications)
import Foundation
import MHDeepLinking
import MHNotificationPayloads
import MHPlatformTesting
import Testing

@MainActor
struct MHNotificationRouteDestinationTests {
    @Test
    func deliverRouteURL_stores_payload_route_in_inbox_destination() async {
        let payload = MHNotificationPayload(
            routes: .init(
                defaultRouteURL: url("mhplatform://item?id=rent")
            )
        )
        let inbox = MHDeepLinkInbox()

        let outcome = await MHNotificationOrchestrator.deliverRouteURL(
            payload: payload,
            response: .init(
                actionIdentifier: "com.apple.UNNotificationDefaultActionIdentifier"
            ),
            destination: inbox
        )

        #expect(outcome == .init(
            routeURL: url("mhplatform://item?id=rent"),
            source: .payload
        ))
        #expect(await inbox.consumeLatest() == url("mhplatform://item?id=rent"))
    }

    @Test
    func deliverRouteURL_stores_payload_route_in_observable_inbox_destination() async {
        let payload = MHNotificationPayload(
            routes: .init(
                defaultRouteURL: nil,
                actionRouteURLs: [
                    "view-month": url("mhplatform://month?year=2026&month=1")
                ]
            )
        )
        let inbox = MHObservableDeepLinkInbox()

        let outcome = await MHNotificationOrchestrator.deliverRouteURL(
            payload: payload,
            response: .init(
                actionIdentifier: "view-month"
            ),
            destination: inbox
        )

        #expect(outcome == .init(
            routeURL: url("mhplatform://month?year=2026&month=1"),
            source: MHNotificationRouteDeliveryOutcome.Source.payload
        ))
        #expect(inbox.pendingURL == url("mhplatform://month?year=2026&month=1"))
    }

    @Test
    func deliverRouteURL_stores_and_clears_store_destination() async throws {
        let suiteName = "MHNotificationRouteDeliveryStoreDestinationTests"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        userDefaults.removePersistentDomain(forName: suiteName)

        let store = MHDeepLinkStore(
            userDefaults: userDefaults,
            key: "pendingURL"
        )

        let payloadOutcome = await MHNotificationOrchestrator.deliverRouteURL(
            payload: .init(
                routes: .init(
                    defaultRouteURL: url("mhplatform://recipe?id=tea")
                )
            ),
            response: .init(
                actionIdentifier: "com.apple.UNNotificationDefaultActionIdentifier"
            ),
            destination: store
        )
        #expect(payloadOutcome == .init(
            routeURL: url("mhplatform://recipe?id=tea"),
            source: .payload
        ))
        #expect(store.consumeLatest() == url("mhplatform://recipe?id=tea"))

        store.replacePendingURL(url("mhplatform://recipe?id=stale"))
        let clearOutcome = await MHNotificationOrchestrator.deliverRouteURL(
            MHNotificationRouteDeliveryOutcome(
                routeURL: nil,
                source: .noRoute
            ),
            destination: store,
            clearPendingURLWhenNoRoute: true
        )

        #expect(clearOutcome == .init(
            routeURL: nil,
            source: .noRoute
        ))
        #expect(store.consumeLatest() == nil)
    }

    @Test
    func deliverRouteURL_stores_payload_route_in_recorder_destination() async {
        let recorder = MHDeepLinkURLRecorder()

        let outcome = await MHNotificationOrchestrator.deliverRouteURL(
            payload: .init(
                routes: .init(
                    defaultRouteURL: url("mhplatform://item?id=tea")
                )
            ),
            response: .init(
                actionIdentifier: "com.apple.UNNotificationDefaultActionIdentifier"
            ),
            destination: recorder
        )

        #expect(outcome == .init(
            routeURL: url("mhplatform://item?id=tea"),
            source: .payload
        ))
        #expect(await recorder.latestURL() == url("mhplatform://item?id=tea"))
        #expect(await recorder.pendingURLHistoryValue() == [
            url("mhplatform://item?id=tea")
        ])
    }
}

private func url(_ value: String) -> URL {
    guard let parsedURL = URL(string: value) else {
        preconditionFailure("Invalid URL value: \(value)")
    }
    return parsedURL
}
#endif
