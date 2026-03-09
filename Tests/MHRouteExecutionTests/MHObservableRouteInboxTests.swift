import Foundation
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

    @Test
    func deliver_without_handler_buffers_latest_pending_route_and_suppresses_duplicates() async {
        let inbox = MHObservableRouteInbox<Int>(
            isDuplicate: ==
        )

        await inbox.deliver(12)
        await inbox.deliver(12)
        await inbox.deliver(34)

        #expect(inbox.pendingRoute == 34)
    }

    @Test
    func resynchronizePendingRoutesIfPossible_replays_pending_route_after_handler_registration() async {
        let inbox = MHObservableRouteInbox<Int>(
            pendingRoute: 21,
            isDuplicate: ==
        )
        var appliedRoutes = [Int]()

        inbox.registerHandler { route in
            appliedRoutes.append(route)
        }
        await inbox.resynchronizePendingRoutesIfPossible()

        #expect(appliedRoutes == [21])
        #expect(inbox.pendingRoute == nil)
    }

    @Test
    func deliver_keeps_latest_pending_route_when_handler_throws() async {
        var appliedRoutes = [Int]()
        var failureDescriptions = [String]()
        let inbox = MHObservableRouteInbox<Int>(
            isDuplicate: ==
        ) { route, error in
            failureDescriptions.append("\(route):\(error.localizedDescription)")
        }

        inbox.registerHandler { route in
            appliedRoutes.append(route)
            throw TestError.route(route)
        }

        await inbox.deliver(7)
        await inbox.deliver(7)
        await inbox.deliver(9)

        #expect(appliedRoutes == [7, 9])
        #expect(inbox.pendingRoute == 9)
        #expect(
            failureDescriptions == [
                "7:Route handler failed for 7.",
                "9:Route handler failed for 9."
            ]
        )
    }
}

private extension MHObservableRouteInboxTests {
    enum TestError: LocalizedError {
        case route(Int)

        var errorDescription: String? {
            switch self {
            case .route(let route):
                "Route handler failed for \(route)."
            }
        }
    }
}
