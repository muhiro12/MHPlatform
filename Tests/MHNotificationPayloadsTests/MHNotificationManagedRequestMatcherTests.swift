#if canImport(UserNotifications)
import MHNotificationPayloads
import Testing
import UserNotifications

@MainActor
struct MHNotificationManagedRequestMatcherTests {
    @Test
    func replaceManagedPendingRequests_withPrefixMatcher_removes_managed_only() async {
        let center = NotificationCenterDouble(
            authorizationStatus: .authorized,
            pendingRequests: [
                request(identifier: "managed.old"),
                request(identifier: "foreign.keep")
            ]
        )

        let result = await MHNotificationOrchestrator.replaceManagedPendingRequests(
            center: center,
            requests: [request(identifier: "managed.new")],
            matcher: .init(prefixes: ["managed."])
        )

        #expect(result.removedPendingIdentifiers == ["managed.old"])
        #expect(result.addedRequestIdentifiers == ["managed.new"])
        #expect(result.failedRequestIdentifiers.isEmpty)
        #expect(center.pendingIdentifiers() == ["foreign.keep", "managed.new"])
    }

    @Test
    func replaceManagedPendingRequests_withExactMatcher_removes_exact_identifiers_only() async {
        let center = NotificationCenterDouble(
            authorizationStatus: .authorized,
            pendingRequests: [
                request(identifier: "managed.keep"),
                request(identifier: "managed.remove"),
                request(identifier: "managed.remove.preview")
            ]
        )

        let result = await MHNotificationOrchestrator.replaceManagedPendingRequests(
            center: center,
            requests: [request(identifier: "managed.keep")],
            matcher: .init(exactIdentifiers: ["managed.remove"])
        )

        #expect(result.removedPendingIdentifiers == ["managed.remove"])
        #expect(result.addedRequestIdentifiers == ["managed.keep"])
        #expect(result.failedRequestIdentifiers.isEmpty)
        #expect(center.pendingIdentifiers() == [
            "managed.keep",
            "managed.remove.preview"
        ])
    }

    @Test
    func replaceManagedPendingRequests_withMixedMatcher_combines_prefix_and_exact_matches() async {
        let center = NotificationCenterDouble(
            authorizationStatus: .authorized,
            pendingRequests: [
                request(identifier: "managed.remove"),
                request(identifier: "preview.keep"),
                request(identifier: "preview.remove"),
                request(identifier: "foreign.keep")
            ]
        )

        let result = await MHNotificationOrchestrator.replaceManagedPendingRequests(
            center: center,
            requests: [
                request(identifier: "managed.new"),
                request(identifier: "preview.keep")
            ],
            matcher: .init(
                prefixes: ["managed."],
                exactIdentifiers: ["preview.keep"]
            )
        )

        #expect(result.removedPendingIdentifiers == ["managed.remove"])
        #expect(result.addedRequestIdentifiers == [
            "managed.new",
            "preview.keep"
        ])
        #expect(result.failedRequestIdentifiers.isEmpty)
        #expect(center.pendingIdentifiers() == [
            "foreign.keep",
            "managed.new",
            "preview.keep",
            "preview.remove"
        ])
    }

    @Test
    func replaceManagedPendingRequests_withMatcher_leaves_pending_requests_when_nothing_matches() async {
        let center = NotificationCenterDouble(
            authorizationStatus: .authorized,
            pendingRequests: [
                request(identifier: "foreign.keep"),
                request(identifier: "preview.keep")
            ]
        )

        let result = await MHNotificationOrchestrator.replaceManagedPendingRequests(
            center: center,
            requests: [request(identifier: "managed.new")],
            matcher: .init(
                prefixes: ["managed."],
                exactIdentifiers: ["managed.preview"]
            )
        )

        #expect(result.removedPendingIdentifiers.isEmpty)
        #expect(result.addedRequestIdentifiers == ["managed.new"])
        #expect(result.failedRequestIdentifiers.isEmpty)
        #expect(center.pendingIdentifiers() == [
            "foreign.keep",
            "managed.new",
            "preview.keep"
        ])
    }
}
#endif
