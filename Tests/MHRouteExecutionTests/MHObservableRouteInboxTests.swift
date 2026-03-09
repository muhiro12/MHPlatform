@testable import MHRouteExecution
import Testing

@MainActor
struct MHObservableRouteInboxTests {
    @Test
    func replacePendingRoute_keeps_latest_route() {
        let inbox = MHObservableRouteInbox<Int>()

        inbox.replacePendingRoute(12)
        inbox.replacePendingRoute(34)

        #expect(inbox.pendingRoute == 34)
    }

    @Test
    func consumeLatest_returns_pending_route_once_and_clears_it() {
        let inbox = MHObservableRouteInbox<Int>(
            pendingRoute: 42
        )

        #expect(inbox.consumeLatest() == 42)
        #expect(inbox.pendingRoute == nil)
        #expect(inbox.consumeLatest() == nil)
    }

    @Test
    func clearPendingRoute_removes_pending_route_immediately() {
        let inbox = MHObservableRouteInbox<Int>(
            pendingRoute: 99
        )

        inbox.clearPendingRoute()

        #expect(inbox.pendingRoute == nil)
        #expect(inbox.consumeLatest() == nil)
    }
}
