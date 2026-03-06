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
}

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
