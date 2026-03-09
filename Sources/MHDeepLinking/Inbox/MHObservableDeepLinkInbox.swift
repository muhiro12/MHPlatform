import Foundation
import Observation

/// Main-actor observable deep-link inbox that mirrors the latest pending URL.
@MainActor
@preconcurrency
@Observable
public final class MHObservableDeepLinkInbox: @unchecked Sendable {
    /// Latest pending URL mirrored for observation.
    public private(set) var pendingURL: URL?

    private let inbox: MHDeepLinkInbox

    /// Creates an observable wrapper around an in-memory deep-link inbox.
    public init(inbox: MHDeepLinkInbox = MHDeepLinkInbox()) {
        self.inbox = inbox
    }

    /// Ingests a pending URL and replaces any previous one.
    public func ingest(_ url: URL) async {
        await setPendingURL(url)
    }

    /// Consumes and clears the latest pending URL.
    public func consumeLatest() async -> URL? {
        let currentURL = await inbox.consumeLatest()
        pendingURL = nil
        return currentURL
    }

    /// Clears any pending URL and updates the observable mirror.
    public func clear() async {
        await setPendingURL(nil)
    }

    /// Replaces the pending URL, or clears it when `nil` is provided.
    public func replacePendingURL(_ url: URL?) async {
        await setPendingURL(url)
    }

    /// Stores a pending URL, or clears the inbox when `nil` is provided.
    public func setPendingURL(_ url: URL?) async {
        await inbox.setPendingURL(url)
        pendingURL = url
    }
}

extension MHObservableDeepLinkInbox: MHDeepLinkURLSource {
    /// Consumes and clears the latest pending URL.
    public func consumeLatestURL() async -> URL? {
        await consumeLatest()
    }
}

extension MHObservableDeepLinkInbox: MHDeepLinkURLDestination {}

public extension MHObservableDeepLinkInbox {
    /// Builds a URL for the route, stores it in memory, and returns the stored URL.
    @discardableResult
    func ingest<Route: MHDeepLinkRoute & Sendable>(
        _ route: Route,
        using codec: MHDeepLinkCodec<Route>,
        transport: MHDeepLinkTransport? = nil
    ) async -> URL? {
        let url = await inbox.ingest(
            route,
            using: codec,
            transport: transport
        )
        if let url {
            pendingURL = url
        }
        return url
    }

    /// Consumes the latest pending URL and parses it into an app-owned route.
    func consumeLatest<Route: MHDeepLinkRoute & Sendable>(
        using codec: MHDeepLinkCodec<Route>
    ) async -> Route? {
        let route = await inbox.consumeLatest(using: codec)
        pendingURL = nil
        return route
    }
}
