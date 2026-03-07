import Foundation
import MHDeepLinking
import MHLogging

/// Shared route lifecycle driver for parsed URLs and app-owned route application.
public actor MHRouteLifecycle<Route: Sendable> {
    /// Callback used to decide whether two routes are duplicates while queued.
    public typealias DuplicatePredicate = @Sendable (Route, Route) -> Bool
    /// Parses an external URL into an app-owned route.
    public typealias RouteParser = @Sendable (URL) -> Route?
    /// Applies a resolved route on the main actor.
    public typealias RouteApplier = @MainActor @Sendable (Route) async throws -> Void

    private let coordinator: MHRouteCoordinator<Route, Route>
    private let logger: MHLogger

    /// Returns whether a pending route currently exists.
    public var hasPendingRoute: Bool {
        get async {
            await coordinator.hasPendingRoute
        }
    }

    /// Returns the current readiness gate state.
    public var isReady: Bool {
        get async {
            await coordinator.isReady
        }
    }

    /// Creates a lifecycle driver backed by the shared route coordinator.
    @preconcurrency
    public init(
        logger: MHLogger,
        initialReadiness: Bool = false,
        isDuplicate: @escaping DuplicatePredicate = { _, _ in
            false
        }
    ) {
        self.coordinator = .init(
            initialReadiness: initialReadiness,
            isDuplicate: isDuplicate
        )
        self.logger = logger
    }

    /// Sets the readiness gate state for route execution.
    public func setReadiness(_ isReady: Bool) async {
        await coordinator.setReadiness(isReady)
    }

    /// Opens readiness and immediately replays the current pending route when present.
    @discardableResult
    @preconcurrency
    public func activate(
        applyOnMainActor: @escaping RouteApplier
    ) async throws -> MHRouteExecutionOutcome<Route>? {
        await coordinator.setReadiness(true)
        return try await applyPendingIfReady(
            applyOnMainActor: applyOnMainActor
        )
    }

    /// Submits a route for execution and logs the lifecycle outcome.
    @discardableResult
    @preconcurrency
    public func submit(
        _ route: Route,
        applyOnMainActor: @escaping RouteApplier
    ) async throws -> MHRouteExecutionOutcome<Route> {
        let outcome = try await coordinator.submit(
            route,
            applyOnMainActor: applyOnMainActor
        )
        await logExecutionOutcome(outcome)
        return outcome
    }

    /// Applies the current pending route when execution is ready and logs the outcome.
    @discardableResult
    @preconcurrency
    public func applyPendingIfReady(
        applyOnMainActor: @escaping RouteApplier
    ) async throws -> MHRouteExecutionOutcome<Route>? {
        guard let outcome = try await coordinator.applyPendingIfReady(
            applyOnMainActor: applyOnMainActor
        ) else {
            return nil
        }
        await logExecutionOutcome(outcome)
        return outcome
    }

    /// Parses an incoming URL and submits the resolved route when parsing succeeds.
    @discardableResult
    @preconcurrency
    public func submit(
        _ url: URL,
        parse: RouteParser,
        applyOnMainActor: @escaping RouteApplier
    ) async throws -> MHRouteExecutionOutcome<Route>? {
        guard let route = parse(url) else {
            await logger.logImmediately(
                .info,
                "ignored deep-link URL because parsing failed"
            )
            return nil
        }

        await logger.logImmediately(
            .info,
            "accepted deep-link URL for route handling"
        )
        return try await submit(
            route,
            applyOnMainActor: applyOnMainActor
        )
    }

    /// Consumes the latest pending URL from an in-memory inbox and submits it when present.
    @discardableResult
    @preconcurrency
    public func submitLatest<Source: MHDeepLinkURLSource>(
        from source: Source,
        parse: RouteParser,
        applyOnMainActor: @escaping RouteApplier
    ) async throws -> MHRouteExecutionOutcome<Route>? {
        try await submitLatestFromSource(
            source,
            parse: parse,
            applyOnMainActor: applyOnMainActor
        )
    }

    /// Consumes the latest pending URL from an in-memory inbox and submits it when present.
    @discardableResult
    @preconcurrency
    public func submitLatest(
        from inbox: MHDeepLinkInbox,
        parse: RouteParser,
        applyOnMainActor: @escaping RouteApplier
    ) async throws -> MHRouteExecutionOutcome<Route>? {
        try await submitLatestFromSource(
            inbox,
            parse: parse,
            applyOnMainActor: applyOnMainActor
        )
    }

    /// Consumes the latest pending URL from an observable inbox and submits it when present.
    @discardableResult
    @preconcurrency
    public func submitLatest(
        from inbox: MHObservableDeepLinkInbox,
        parse: RouteParser,
        applyOnMainActor: @escaping RouteApplier
    ) async throws -> MHRouteExecutionOutcome<Route>? {
        try await submitLatestFromSource(
            inbox,
            parse: parse,
            applyOnMainActor: applyOnMainActor
        )
    }

    /// Consumes the latest pending URL from persistent storage and submits it when present.
    @discardableResult
    @preconcurrency
    public func submitLatest(
        from store: MHDeepLinkStore,
        parse: RouteParser,
        applyOnMainActor: @escaping RouteApplier
    ) async throws -> MHRouteExecutionOutcome<Route>? {
        try await submitLatestFromSource(
            store,
            parse: parse,
            applyOnMainActor: applyOnMainActor
        )
    }
}

private extension MHRouteLifecycle {
    @preconcurrency
    func submitLatestFromSource(
        _ source: some MHDeepLinkURLSource,
        parse: RouteParser,
        applyOnMainActor: @escaping RouteApplier
    ) async throws -> MHRouteExecutionOutcome<Route>? {
        guard let url = await source.consumeLatestURL() else {
            return nil
        }

        return try await submit(
            url,
            parse: parse,
            applyOnMainActor: applyOnMainActor
        )
    }

    func logExecutionOutcome(
        _ outcome: MHRouteExecutionOutcome<Route>
    ) async {
        switch outcome {
        case .applied:
            await logger.logImmediately(
                .notice,
                "route applied"
            )
        case .queued:
            await logger.logImmediately(
                .info,
                "route queued until execution becomes ready"
            )
        case .deduplicated:
            await logger.logImmediately(
                .info,
                "route deduplicated against pending route"
            )
        }
    }
}
