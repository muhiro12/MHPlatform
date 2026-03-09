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
    /// Latest pending route mirrored for observation.
    public private(set) var pendingRoute: Route?

    /// Creates an observable inbox around an optional initial route.
    public init(
        pendingRoute: Route? = nil
    ) {
        self.pendingRoute = pendingRoute
    }

    /// Replaces the latest pending route.
    public func replacePendingRoute(
        _ route: Route
    ) {
        pendingRoute = route
    }

    /// Consumes and clears the latest pending route.
    public func consumeLatest() -> Route? {
        let route = pendingRoute
        pendingRoute = nil
        return route
    }

    /// Clears any pending route.
    public func clearPendingRoute() {
        pendingRoute = nil
    }
}
