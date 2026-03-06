#if canImport(UserNotifications)
import Foundation
import MHNotificationPayloads
import Testing
import UserNotifications

@MainActor
struct MHNotificationOrchestratorTests {
    @Test
    func registerCategories_registers_all_descriptors() {
        let center = NotificationCenterDouble(
            authorizationStatus: .authorized,
            pendingRequests: []
        )

        MHNotificationOrchestrator.registerCategories(
            [
                .init(
                    identifier: "upcoming-payment.actions",
                    actions: [
                        .init(identifier: "view-item", title: "View Item"),
                        .init(identifier: "view-month", title: "View Month")
                    ]
                ),
                .init(
                    identifier: "daily_recipe_suggestion",
                    actions: [
                        .init(identifier: "browse_recipes", title: "Browse Recipes")
                    ]
                )
            ],
            center: center
        )

        #expect(center.categoryIdentifiersValue() == [
            "daily_recipe_suggestion",
            "upcoming-payment.actions"
        ])
    }

    @Test
    func requestAuthorizationIfNeeded_requests_when_status_is_not_determined() async {
        let center = NotificationCenterDouble(
            authorizationStatus: .notDetermined,
            pendingRequests: [],
            authorizationStatusAfterRequest: .authorized
        )

        let status = await MHNotificationOrchestrator.requestAuthorizationIfNeeded(
            center: center,
            options: [.alert],
            requestIfNotDetermined: true
        )

        #expect(status == .authorized)
        #expect(center.requestAuthorizationCallCountValue() == 1)
    }

    @Test
    func requestAuthorizationIfNeeded_skips_request_for_authorized_or_denied() async {
        for initialStatus in [UNAuthorizationStatus.authorized, .denied] {
            let center = NotificationCenterDouble(
                authorizationStatus: initialStatus,
                pendingRequests: []
            )

            let status = await MHNotificationOrchestrator.requestAuthorizationIfNeeded(
                center: center,
                options: [.alert],
                requestIfNotDetermined: true
            )

            #expect(status == initialStatus)
            #expect(center.requestAuthorizationCallCountValue() == 0)
        }
    }

    @Test
    func replaceManagedPendingRequests_removes_managed_only() async {
        let center = NotificationCenterDouble(
            authorizationStatus: .authorized,
            pendingRequests: [
                request(identifier: "managed.old"),
                request(identifier: "foreign.keep")
            ]
        )

        let result = await MHNotificationOrchestrator.replaceManagedPendingRequests(
            center: center,
            requests: [request(identifier: "managed.new")]
        ) { identifier in
            identifier.hasPrefix("managed.")
        }

        #expect(result.removedPendingIdentifiers == ["managed.old"])
        #expect(result.addedRequestIdentifiers == ["managed.new"])
        #expect(result.failedRequestIdentifiers.isEmpty)
        #expect(center.pendingIdentifiers() == ["foreign.keep", "managed.new"])
    }

    @Test
    func replaceManagedPendingRequests_continues_after_add_failures() async {
        let center = NotificationCenterDouble(
            authorizationStatus: .authorized,
            pendingRequests: [],
            failingAddIdentifiers: ["managed.fail"]
        )

        let result = await MHNotificationOrchestrator.replaceManagedPendingRequests(
            center: center,
            requests: [
                request(identifier: "managed.good.1"),
                request(identifier: "managed.fail"),
                request(identifier: "managed.good.2")
            ]
        ) { _ in
            true
        }

        #expect(result.addedRequestIdentifiers == [
            "managed.good.1",
            "managed.good.2"
        ])
        #expect(result.failedRequestIdentifiers == ["managed.fail"])
        #expect(center.addAttemptIdentifiersValue() == [
            "managed.good.1",
            "managed.fail",
            "managed.good.2"
        ])
        #expect(center.pendingIdentifiers() == [
            "managed.good.1",
            "managed.good.2"
        ])
    }

    @Test
    func replaceManagedPendingRequests_keeps_existing_request_when_replacement_fails() async {
        let center = NotificationCenterDouble(
            authorizationStatus: .authorized,
            pendingRequests: [
                request(identifier: "managed.keep"),
                request(identifier: "managed.remove"),
                request(identifier: "foreign.keep")
            ],
            failingAddIdentifiers: ["managed.keep"]
        )

        let result = await MHNotificationOrchestrator.replaceManagedPendingRequests(
            center: center,
            requests: [
                request(identifier: "managed.keep"),
                request(identifier: "managed.new")
            ]
        ) { identifier in
            identifier.hasPrefix("managed.")
        }

        #expect(result.removedPendingIdentifiers == ["managed.remove"])
        #expect(result.addedRequestIdentifiers == ["managed.new"])
        #expect(result.failedRequestIdentifiers == ["managed.keep"])
        #expect(center.pendingIdentifiers() == [
            "foreign.keep",
            "managed.keep",
            "managed.new"
        ])
    }

    @Test
    func resolveRouteURL_applies_expected_precedence() {
        let codec = MHNotificationPayloadCodec()
        let payload = MHNotificationPayload(
            routes: .init(
                defaultRouteURL: url("mhplatform://item?id=rent"),
                fallbackRouteURL: url("mhplatform://month?year=2026&month=1"),
                actionRouteURLs: [
                    "view-month": url("mhplatform://month?year=2026&month=1")
                ]
            )
        )
        let userInfo = codec.encode(payload)

        #expect(
            MHNotificationOrchestrator.resolveRouteURL(
                userInfo: userInfo,
                actionIdentifier: "view-month",
                codec: codec
            ) == url("mhplatform://month?year=2026&month=1")
        )

        #expect(
            MHNotificationOrchestrator.resolveRouteURL(
                userInfo: userInfo,
                actionIdentifier: "unknown",
                codec: codec
            ) == url("mhplatform://item?id=rent")
        )

        #expect(
            MHNotificationOrchestrator.resolveRouteURL(
                userInfo: userInfo,
                actionIdentifier: "com.apple.UNNotificationDismissActionIdentifier",
                codec: codec
            ) == nil
        )

        let fallbackOnlyPayload = MHNotificationPayload(
            routes: .init(
                defaultRouteURL: nil,
                fallbackRouteURL: url("mhplatform://month?year=2026&month=1")
            )
        )
        let fallbackOnlyUserInfo = codec.encode(fallbackOnlyPayload)

        #expect(
            MHNotificationOrchestrator.resolveRouteURL(
                userInfo: fallbackOnlyUserInfo,
                actionIdentifier: "unknown",
                codec: codec
            ) == url("mhplatform://month?year=2026&month=1")
        )
    }
}

private func request(identifier: String) -> UNNotificationRequest {
    let content = UNMutableNotificationContent()
    content.title = "Title"
    content.body = "Body"

    return .init(
        identifier: identifier,
        content: content,
        trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
    )
}

private func url(_ value: String) -> URL {
    guard let parsedURL = URL(string: value) else {
        preconditionFailure("Invalid URL value: \(value)")
    }
    return parsedURL
}
#endif
