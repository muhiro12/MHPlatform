import Observation

/// Main-actor observable inbox that stores the latest pending route value.
///
/// Use this as a package-owned bridge between route execution and an app-owned
/// navigation model when the app wants replace-latest route handoff without
/// moving route meaning into MHPlatform.
@MainActor
@preconcurrency
@Observable
public final class MHObservableRouteInbox<Route: Sendable>: @unchecked Sendable {
    /// Applies a route into app-owned navigation state on the main actor.
    public typealias Handler = @MainActor @Sendable (Route) async throws -> Void
    /// Decides whether two routes should be treated as duplicates while pending.
    public typealias DuplicatePredicate = @Sendable (Route, Route) -> Bool
    /// Reports a handler failure while keeping the latest route buffered.
    public typealias FailureHandler = @MainActor @Sendable (Route, any Error) -> Void

    /// Latest pending route mirrored for observation.
    public private(set) var pendingRoute: Route?

    @ObservationIgnored private var handler: Handler?

    @ObservationIgnored private let isDuplicate: DuplicatePredicate

    @ObservationIgnored private let onFailure: FailureHandler

    @ObservationIgnored private var pendingRouteVersion: UInt = 0

    /// Creates an observable inbox around an optional initial route.
    public init(
        pendingRoute: Route? = nil,
        isDuplicate: @escaping DuplicatePredicate = { _, _ in
            false
        },
        onFailure: @escaping FailureHandler = { _, _ in
            // no-op
        }
    ) {
        self.pendingRoute = pendingRoute
        self.isDuplicate = isDuplicate
        self.onFailure = onFailure
    }

    /// Replaces the latest pending route.
    public func replacePendingRoute(
        _ route: Route
    ) {
        setPendingRoute(route)
    }

    /// Consumes and clears the latest pending route.
    public func consumeLatest() -> Route? {
        let route = pendingRoute
        clearPendingRoute()
        return route
    }

    /// Clears any pending route.
    public func clearPendingRoute() {
        pendingRoute = nil
        pendingRouteVersion += 1
    }

    /// Registers a route handler for package-owned replay and buffering.
    public func registerHandler(
        _ handler: @escaping Handler
    ) {
        self.handler = handler
    }

    /// Removes the currently registered route handler.
    public func unregisterHandler() {
        handler = nil
    }

    /// Delivers a route when possible, otherwise buffering the latest route.
    ///
    /// Duplicate routes that match the current pending route are suppressed.
    public func deliver(
        _ route: Route
    ) async {
        await deliver(
            route,
            suppressingPendingDuplicates: true
        )
    }

    /// Replays the latest pending route when a handler is available.
    public func resynchronizePendingRoutesIfPossible() async {
        guard let pendingRoute else {
            return
        }

        await deliver(
            pendingRoute,
            suppressingPendingDuplicates: false
        )
    }
}

private extension MHObservableRouteInbox {
    func deliver(
        _ route: Route,
        suppressingPendingDuplicates: Bool
    ) async {
        if suppressingPendingDuplicates,
           isPendingDuplicate(of: route) {
            return
        }

        guard let handler else {
            setPendingRoute(route)
            return
        }

        let versionBeforeHandling = pendingRouteVersion

        do {
            try await handler(route)
            if pendingRouteVersion == versionBeforeHandling {
                clearPendingRoute()
            }
        } catch {
            onFailure(route, error)
            setPendingRoute(route)
        }
    }

    func setPendingRoute(_ route: Route) {
        pendingRoute = route
        pendingRouteVersion += 1
    }

    func isPendingDuplicate(of route: Route) -> Bool {
        guard let pendingRoute else {
            return false
        }

        return isDuplicate(pendingRoute, route)
    }
}
