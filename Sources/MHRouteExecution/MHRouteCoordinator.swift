/// Coordinates route handling with readiness checks and a latest-wins pending queue.
public actor MHRouteCoordinator<Route: Sendable, Outcome: Sendable> {
    private let isReady: @Sendable () -> Bool
    private let executor: MHRouteExecutor<Route, Outcome>

    private var pendingRoute: Route?
    private var isExecuting = false

    /// Returns whether a pending route currently exists.
    public var hasPendingRoute: Bool {
        pendingRoute != nil
    }

    /// Creates a coordinator with the supplied readiness callback and executor.
    @preconcurrency
    public init(
        isReady: @escaping @Sendable () -> Bool,
        executor: MHRouteExecutor<Route, Outcome>
    ) {
        self.isReady = isReady
        self.executor = executor
    }

    /// Handles an incoming route, applying it when possible or queueing it otherwise.
    public func handle(_ route: Route) async throws -> MHRouteResolution<Outcome> {
        guard canExecuteNow else {
            pendingRoute = route
            return .queued
        }

        let outcome = try await execute(route)
        return .applied(outcome)
    }

    /// Applies the current pending route when possible.
    public func applyPendingIfNeeded() async throws -> MHRouteResolution<Outcome>? {
        guard let pendingRoute else {
            return nil
        }

        guard canExecuteNow else {
            return .queued
        }

        self.pendingRoute = nil

        do {
            let outcome = try await execute(pendingRoute)
            return .applied(outcome)
        } catch {
            if self.pendingRoute == nil {
                self.pendingRoute = pendingRoute
            }
            throw error
        }
    }

    /// Clears the pending route.
    public func clearPendingRoute() {
        pendingRoute = nil
    }
}

private extension MHRouteCoordinator {
    var canExecuteNow: Bool {
        isReady() && isExecuting == false
    }

    func execute(_ route: Route) async throws -> Outcome {
        isExecuting = true
        defer {
            isExecuting = false
        }
        return try await executor.execute(route)
    }
}
