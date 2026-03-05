/// Resolves and applies routes with app-provided asynchronous closures.
public struct MHRouteExecutor<Route: Sendable, Outcome: Sendable>: Sendable {
    private let resolve: @Sendable (Route) async throws -> Outcome
    private let apply: @Sendable (Outcome) async throws -> Void

    /// Creates an executor that first resolves and then applies a route outcome.
    @preconcurrency
    public init(
        resolve: @escaping @Sendable (Route) async throws -> Outcome,
        apply: @escaping @Sendable (Outcome) async throws -> Void
    ) {
        self.resolve = resolve
        self.apply = apply
    }

    /// Resolves and applies a route, then returns the resolved outcome.
    @discardableResult
    public func execute(_ route: Route) async throws -> Outcome {
        let outcome = try await resolve(route)
        try await apply(outcome)
        return outcome
    }
}
