import Foundation

/// In-memory pending deep-link inbox that is safe across concurrent tasks.
public actor MHDeepLinkInbox {
    private var pendingURL: URL?

    /// Creates an empty inbox.
    public init() {
        // Intentionally empty.
    }

    /// Ingests a pending URL and replaces any previous one.
    public func ingest(_ url: URL) {
        pendingURL = url
    }

    /// Consumes and clears the latest pending URL.
    public func consumeLatest() -> URL? {
        let currentURL = pendingURL
        pendingURL = nil
        return currentURL
    }

    /// Clears any pending URL without consuming it.
    public func clear() {
        setPendingURL(nil)
    }

    /// Replaces the pending URL, or clears it when `nil` is provided.
    public func replacePendingURL(_ url: URL?) {
        setPendingURL(url)
    }

    /// Stores a pending URL, or clears the inbox when `nil` is provided.
    public func setPendingURL(_ url: URL?) {
        pendingURL = url
    }
}

extension MHDeepLinkInbox: MHDeepLinkURLSource {
    /// Consumes and clears the latest pending URL.
    public func consumeLatestURL() async -> URL? { // swiftlint:disable:this async_without_await
        consumeLatest()
    }
}

extension MHDeepLinkInbox: MHDeepLinkURLDestination {}

public extension MHDeepLinkInbox {
    /// Builds a URL for the route, stores it in memory, and returns the stored URL.
    @discardableResult
    func ingest<Route: MHDeepLinkRoute>(
        _ route: Route,
        using codec: MHDeepLinkCodec<Route>,
        transport: MHDeepLinkTransport? = nil
    ) -> URL? {
        let url = resolveURL(
            for: route,
            using: codec,
            transport: transport
        )
        guard let url else {
            return nil
        }

        ingest(url)
        return url
    }

    /// Consumes the latest pending URL and parses it into an app-owned route.
    func consumeLatest<Route: MHDeepLinkRoute>(
        using codec: MHDeepLinkCodec<Route>
    ) -> Route? {
        guard let url = consumeLatest() else {
            return nil
        }
        return codec.parse(url)
    }
}

private extension MHDeepLinkInbox {
    func resolveURL<Route: MHDeepLinkRoute>(
        for route: Route,
        using codec: MHDeepLinkCodec<Route>,
        transport: MHDeepLinkTransport?
    ) -> URL? {
        if let transport {
            return codec.url(
                for: route,
                transport: transport
            )
        }

        return codec.preferredURL(for: route)
    }
}
