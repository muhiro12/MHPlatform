import Combine
import Foundation
import MHRouteExecution

@MainActor
final class RouteExecutionDemoModel: ObservableObject {
    private enum Constants {
        static let resolveDelayMilliseconds = 150
        static let applyDelayMilliseconds = 90
    }

    @Published private(set) var isReady = true
    @Published private(set) var hasPendingRoute = false
    @Published private(set) var logs = [String]()

    private let coordinator: MHRouteCoordinator<
        RouteExecutionDemoRoute,
        RouteExecutionDemoOutcome
    >
    private var logSequence = 0

    init() {
        let executor = MHRouteExecutor<
            RouteExecutionDemoRoute,
            RouteExecutionDemoOutcome
        >(
            resolve: { route in
                try await Task.sleep(
                    for: .milliseconds(Constants.resolveDelayMilliseconds)
                )

                switch route {
                case .home:
                    return .init(
                        route: route,
                        destination: "home"
                    )
                case .search:
                    return .init(
                        route: route,
                        destination: "search?q=tea"
                    )
                case .settings:
                    return .init(
                        route: route,
                        destination: "settings/subscription"
                    )
                case .broken:
                    throw RouteExecutionDemoError.resolveFailed
                }
            },
            apply: { _ in
                try await Task.sleep(
                    for: .milliseconds(Constants.applyDelayMilliseconds)
                )
            }
        )

        coordinator = .init(
            initialReadiness: true,
            executor: executor
        )            { lhs, rhs in
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
                let outcome = try await coordinator.submit(route)
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
                let outcome = try await coordinator.applyPendingIfReady()
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
        for outcome: MHRouteExecutionOutcome<RouteExecutionDemoOutcome>,
        source: String
    ) -> String {
        switch outcome {
        case .queued:
            return "\(source): queued"
        case .applied(let resolvedOutcome):
            return "\(source): applied \(resolvedOutcome.destination)"
        case .deduplicated:
            return "\(source): deduplicated"
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
