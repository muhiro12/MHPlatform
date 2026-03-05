/// Coordinates route execution with readiness gating and a latest-wins pending queue.
public actor MHRouteCoordinator<Route: Sendable, Outcome: Sendable> {
    /// Callback used to decide whether two routes are duplicates while queued.
    public typealias DuplicatePredicate = @Sendable (Route, Route) -> Bool

    private let executor: MHRouteExecutor<Route, Outcome>
    private let isDuplicate: DuplicatePredicate

    private var readiness = false
    private var pendingRoute: Route?
    private var isExecuting = false

    /// Returns whether a pending route currently exists.
    public var hasPendingRoute: Bool {
        pendingRoute != nil
    }

    /// Returns the current readiness gate state.
    public var isReady: Bool {
        readiness
    }

    /// Creates a coordinator with explicit readiness state and dedupe behavior.
    @preconcurrency
    public init(
        executor: MHRouteExecutor<Route, Outcome>,
        initialReadiness: Bool = false,
        isDuplicate: @escaping DuplicatePredicate = { _, _ in
            false
        }
    ) {
        self.readiness = initialReadiness
        self.executor = executor
        self.isDuplicate = isDuplicate
    }

    /// Sets readiness gate state.
    public func setReadiness(_ isReady: Bool) {
        readiness = isReady
    }

    /// Submits a route for execution.
    public func submit(_ route: Route) async throws -> MHRouteExecutionOutcome<Outcome> {
        guard canExecuteNow else {
            return enqueue(route)
        }

        let outcome = try await execute(route)
        return .applied(outcome)
    }

    /// Applies the latest pending route when execution is currently possible.
    public func applyPendingIfReady() async throws -> MHRouteExecutionOutcome<Outcome>? {
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
        readiness && isExecuting == false
    }

    func enqueue(_ route: Route) -> MHRouteExecutionOutcome<Outcome> {
        if let pendingRoute,
           isDuplicate(pendingRoute, route) {
            return .deduplicated
        }

        pendingRoute = route
        return .queued
    }

    func execute(_ route: Route) async throws -> Outcome {
        isExecuting = true
        defer {
            isExecuting = false
        }
        return try await executor.execute(route)
    }
}
