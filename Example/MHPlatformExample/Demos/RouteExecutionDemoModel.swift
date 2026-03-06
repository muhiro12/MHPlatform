import Combine
import Foundation
import MHPlatform

@MainActor
final class RouteExecutionDemoModel: ObservableObject {
    private enum Constants {
        static let applyDelayMilliseconds = 90
    }

    @Published private(set) var isReady = true
    @Published private(set) var hasPendingRoute = false
    @Published private(set) var logs = [String]()

    private let coordinator: MHRouteCoordinator<
        RouteExecutionDemoRoute,
        RouteExecutionDemoRoute
    >
    private var logSequence = 0

    init() {
        coordinator = .init(
            initialReadiness: true
        ) { lhs, rhs in
            lhs == rhs
        }
    }

    func setReadiness(_ isReady: Bool) {
        self.isReady = isReady

        appendLog(
            "readiness: \(isReady ? "ready" : "not-ready")"
        )

        Task {
            await coordinator.setReadiness(isReady)
            await refreshPendingRouteStatus()
        }
    }

    func submit(_ route: RouteExecutionDemoRoute) {
        Task {
            do {
                let outcome = try await coordinator.submit(route) { [self] resolvedRoute in
                    try await applyRoute(resolvedRoute)
                }
                appendLog(
                    outcomeMessage(
                        for: outcome,
                        source: "submit(\(route.rawValue))"
                    )
                )
            } catch {
                appendLog(
                    "submit(\(route.rawValue)): error \(describe(error: error))"
                )
            }

            await refreshPendingRouteStatus()
        }
    }

    func applyPendingIfReady() {
        Task {
            do {
                let outcome = try await coordinator.applyPendingIfReady { [self] resolvedRoute in
                    try await applyRoute(resolvedRoute)
                }
                if let outcome {
                    appendLog(
                        outcomeMessage(
                            for: outcome,
                            source: "applyPendingIfReady"
                        )
                    )
                } else {
                    appendLog("applyPendingIfReady: no pending route")
                }
            } catch {
                appendLog(
                    "applyPendingIfReady: error \(describe(error: error))"
                )
            }

            await refreshPendingRouteStatus()
        }
    }

    func clearPendingRoute() {
        Task {
            await coordinator.clearPendingRoute()
            appendLog("clearPendingRoute: cleared")
            await refreshPendingRouteStatus()
        }
    }

    func refreshPendingRouteStatus() async {
        hasPendingRoute = await coordinator.hasPendingRoute
    }

    private func appendLog(_ message: String) {
        logSequence += 1
        logs.insert(
            "\(logSequence). \(message)",
            at: .zero
        )
    }

    private func outcomeMessage(
        for outcome: MHRouteExecutionOutcome<RouteExecutionDemoRoute>,
        source: String
    ) -> String {
        switch outcome {
        case .queued:
            return "\(source): queued"
        case .applied(let route):
            return "\(source): applied \(destination(for: route))"
        case .deduplicated:
            return "\(source): deduplicated"
        }
    }

    private func applyRoute(
        _ route: RouteExecutionDemoRoute
    ) async throws {
        try await Task.sleep(
            for: .milliseconds(Constants.applyDelayMilliseconds)
        )

        if route == .broken {
            throw RouteExecutionDemoError.resolveFailed
        }
    }

    private func destination(
        for route: RouteExecutionDemoRoute
    ) -> String {
        switch route {
        case .home:
            return "home"
        case .search:
            return "search?q=tea"
        case .settings:
            return "settings/subscription"
        case .broken:
            return "broken"
        }
    }

    private func describe(error: any Error) -> String {
        if let localizedError = error as? LocalizedError,
           let errorDescription = localizedError.errorDescription {
            return errorDescription
        }
        return String(describing: error)
    }
}
