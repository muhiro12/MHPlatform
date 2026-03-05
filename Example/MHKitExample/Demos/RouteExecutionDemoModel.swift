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

    private let readinessFlag: RouteExecutionDemoReadinessFlag
    private let coordinator: MHRouteCoordinator<
        RouteExecutionDemoRoute,
        RouteExecutionDemoOutcome
    >
    private var logSequence = 0

    init() {
        let readinessFlag = RouteExecutionDemoReadinessFlag(initialValue: true)
        self.readinessFlag = readinessFlag

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
            isReady: { readinessFlag.value },
            executor: executor
        )
    }

    func setReadiness(_ isReady: Bool) {
        self.isReady = isReady
        readinessFlag.set(isReady)

        appendLog(
            "readiness: \(isReady ? "ready" : "not-ready")"
        )

        Task {
            await refreshPendingRouteStatus()
        }
    }

    func handle(_ route: RouteExecutionDemoRoute) {
        Task {
            do {
                let resolution = try await coordinator.handle(route)
                appendLog(
                    resolutionMessage(
                        for: resolution,
                        source: "handle(\(route.rawValue))"
                    )
                )
            } catch {
                appendLog(
                    "handle(\(route.rawValue)): error \(describe(error: error))"
                )
            }

            await refreshPendingRouteStatus()
        }
    }

    func applyPendingIfNeeded() {
        Task {
            do {
                let resolution = try await coordinator.applyPendingIfNeeded()
                if let resolution {
                    appendLog(
                        resolutionMessage(
                            for: resolution,
                            source: "applyPendingIfNeeded"
                        )
                    )
                } else {
                    appendLog("applyPendingIfNeeded: no pending route")
                }
            } catch {
                appendLog(
                    "applyPendingIfNeeded: error \(describe(error: error))"
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

    private func resolutionMessage(
        for resolution: MHRouteResolution<RouteExecutionDemoOutcome>,
        source: String
    ) -> String {
        switch resolution {
        case .queued:
            return "\(source): queued"
        case .applied(let outcome):
            return "\(source): applied \(outcome.destination)"
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
