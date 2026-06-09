import Foundation
import MHDeepLinking
import MHLogging
import MHRouteExecution
import Observation

/// Package-owned route handoff shell for root app integration.
@MainActor
@preconcurrency
@Observable
public final class MHAppRoutePipeline<Route: Sendable> {
    /// Parses incoming URLs into app-owned routes.
    public typealias RouteParser = @Sendable (URL) -> Route?
    /// Applies parsed routes on the main actor.
    public typealias RouteApplier = MHRouteLifecycle<Route>.RouteApplier
    /// Handles route execution failures surfaced by the pipeline.
    public typealias FailureHandler = @MainActor @Sendable (any Error) -> Void

    /// Observable inbox owned by the pipeline for incoming URLs.
    public let inbox: MHObservableDeepLinkInbox
    /// Latest URL that failed route parsing.
    public private(set) var lastParseFailureURL: URL?

    @ObservationIgnored private let routeLifecycle: MHRouteLifecycle<Route>
    @ObservationIgnored private let pendingSources: [any MHDeepLinkURLSource]
    @ObservationIgnored private let parseRoute: RouteParser
    @ObservationIgnored private let applyOnMainActor: RouteApplier
    @ObservationIgnored private let failureLogger: MHLogger
    @ObservationIgnored private let onFailure: FailureHandler?

    /// Creates a route pipeline with explicit URL parsing.
    @preconcurrency
    public init(
        routeLifecycle: MHRouteLifecycle<Route>,
        parse: @escaping RouteParser,
        pendingSources: [any MHDeepLinkURLSource] = [],
        inbox: MHObservableDeepLinkInbox = .init(),
        applyOnMainActor: @escaping RouteApplier,
        failureLogger: MHLogger? = nil,
        onFailure: FailureHandler? = nil
    ) {
        self.routeLifecycle = routeLifecycle
        self.pendingSources = pendingSources
        self.inbox = inbox
        self.parseRoute = parse
        self.applyOnMainActor = applyOnMainActor
        self.failureLogger = failureLogger ?? Self.defaultFailureLogger
        self.onFailure = onFailure
    }

    /// Creates a route pipeline that stores applied routes in an observable route inbox.
    ///
    /// Use this when the app wants package-owned latest-route handoff before
    /// mutating its own navigation model.
    @preconcurrency
    public convenience init(
        routeLifecycle: MHRouteLifecycle<Route>,
        parse: @escaping RouteParser,
        routeInbox: MHObservableRouteInbox<Route>,
        pendingSources: [any MHDeepLinkURLSource] = [],
        inbox: MHObservableDeepLinkInbox = .init(),
        failureLogger: MHLogger? = nil,
        onFailure: FailureHandler? = nil
    ) {
        self.init(
            routeLifecycle: routeLifecycle,
            parse: parse,
            pendingSources: pendingSources,
            inbox: inbox,
            applyOnMainActor: { route in
                await routeInbox.deliver(route)
            },
            failureLogger: failureLogger,
            onFailure: onFailure
        )
    }

    /// Stores an incoming URL in the pipeline-owned inbox.
    public func ingest(_ url: URL) async {
        await inbox.ingest(url)
    }

    /// Opens route execution readiness once and replays any queued route.
    @discardableResult
    public func activateIfNeeded() async -> MHRouteExecutionOutcome<Route>? {
        guard await routeLifecycle.isReady == false else {
            return nil
        }

        do {
            return try await routeLifecycle.activate(
                applyOnMainActor: applyOnMainActor
            )
        } catch {
            handleFailure(
                error,
                operation: "activateIfNeeded"
            )
            return nil
        }
    }

    /// Consumes at most one pending URL and submits it for route execution.
    @discardableResult
    public func drainPendingRoutesIfNeeded() async -> MHRouteExecutionOutcome<Route>? {
        guard let url = await orderedSources.consumeLatestURL() else {
            return nil
        }
        let parseRoute = self.parseRoute
        let parseFailureBox = ParseFailureBox()

        do {
            let outcome = try await routeLifecycle.submit(
                url,
                parse: { incomingURL in
                    let route = parseRoute(incomingURL)
                    if route == nil {
                        parseFailureBox.url = incomingURL
                    }
                    return route
                },
                applyOnMainActor: applyOnMainActor
            )
            if let failedURL = parseFailureBox.url {
                lastParseFailureURL = failedURL
            }
            return outcome
        } catch {
            handleFailure(
                error,
                operation: "drainPendingRoutesIfNeeded"
            )
            return nil
        }
    }

    /// Replays queued routes when needed, then drains one pending URL.
    @discardableResult
    public func synchronizePendingRoutesIfPossible() async -> MHRouteExecutionOutcome<Route>? {
        _ = await activateIfNeeded()
        return await drainPendingRoutesIfNeeded()
    }

    /// Builds a lifecycle task that synchronizes pending routes once.
    public func task(
        name: String = "synchronizePendingRoutes"
    ) -> MHAppRuntimeTask {
        .init(name: name) {
            _ = await self.synchronizePendingRoutesIfPossible()
        }
    }

    /// Clears the latest retained parse failure URL.
    public func clearLastParseFailure() {
        lastParseFailureURL = nil
    }
}

public extension MHAppRoutePipeline where Route: MHDeepLinkRoute {
    /// Creates a route pipeline backed by a route codec.
    @preconcurrency
    convenience init(
        routeLifecycle: MHRouteLifecycle<Route>,
        using codec: MHDeepLinkCodec<Route>,
        pendingSources: [any MHDeepLinkURLSource] = [],
        inbox: MHObservableDeepLinkInbox = .init(),
        applyOnMainActor: @escaping RouteApplier,
        failureLogger: MHLogger? = nil,
        onFailure: FailureHandler? = nil
    ) {
        self.init(
            routeLifecycle: routeLifecycle,
            parse: { incomingURL in
                codec.parse(incomingURL)
            },
            pendingSources: pendingSources,
            inbox: inbox,
            applyOnMainActor: applyOnMainActor,
            failureLogger: failureLogger,
            onFailure: onFailure
        )
    }

    /// Creates a route pipeline backed by a route codec and observable route inbox.
    ///
    /// Use this when the app wants package-owned latest-route handoff before
    /// mutating its own navigation model.
    @preconcurrency
    convenience init(
        routeLifecycle: MHRouteLifecycle<Route>,
        using codec: MHDeepLinkCodec<Route>,
        routeInbox: MHObservableRouteInbox<Route>,
        pendingSources: [any MHDeepLinkURLSource] = [],
        inbox: MHObservableDeepLinkInbox = .init(),
        failureLogger: MHLogger? = nil,
        onFailure: FailureHandler? = nil
    ) {
        self.init(
            routeLifecycle: routeLifecycle,
            parse: { incomingURL in
                codec.parse(incomingURL)
            },
            routeInbox: routeInbox,
            pendingSources: pendingSources,
            inbox: inbox,
            failureLogger: failureLogger,
            onFailure: onFailure
        )
    }
}

private extension MHAppRoutePipeline {
    final class ParseFailureBox: @unchecked Sendable {
        private let lock = NSLock()
        private var storedURL: URL?

        var url: URL? {
            get {
                lock.withLock {
                    storedURL
                }
            }
            set {
                lock.withLock {
                    storedURL = newValue
                }
            }
        }
    }

    static var defaultFailureLoggerFactory: MHLoggerFactory {
        .osLogDefault
    }

    static var defaultFailureLogger: MHLogger {
        defaultFailureLoggerFactory.logger(
            category: "MHAppRoutePipeline",
            source: #fileID
        )
    }

    var orderedSources: MHDeepLinkSourceChain {
        var orderedSources = pendingSources
        orderedSources.append(inbox)
        return .init(orderedSources)
    }

    func handleFailure(
        _ error: any Error,
        operation: String
    ) {
        failureLogger.error(
            "route pipeline failure",
            metadata: [
                "error": String(describing: error),
                "operation": operation
            ]
        )
        onFailure?(error)
    }
}

private extension NSLock {
    func withLock<Value>(
        _ body: () -> Value
    ) -> Value {
        lock()
        defer {
            unlock()
        }

        return body()
    }
}
