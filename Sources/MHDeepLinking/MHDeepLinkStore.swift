import Foundation

/// UserDefaults-backed pending deep-link storage.
public final class MHDeepLinkStore: @unchecked Sendable {
    private let userDefaults: UserDefaults
    private let key: String

    /// Creates a persistent deep-link store.
    public init(
        userDefaults: UserDefaults,
        key: String
    ) {
        self.userDefaults = userDefaults
        self.key = key
    }

    /// Creates a persistent deep-link store backed by a suite-scoped `UserDefaults`.
    public convenience init?(
        suiteName: String,
        key: String
    ) {
        guard let userDefaults = UserDefaults(suiteName: suiteName) else {
            return nil
        }

        self.init(
            userDefaults: userDefaults,
            key: key
        )
    }

    /// Persists a pending URL.
    public func ingest(_ url: URL) {
        userDefaults.set(url.absoluteString, forKey: key)
    }

    /// Consumes and clears the latest pending URL.
    public func consumeLatest() -> URL? {
        defer {
            userDefaults.removeObject(forKey: key)
        }

        guard let urlString = userDefaults.string(forKey: key) else {
            return nil
        }
        return URL(string: urlString)
    }
}

extension MHDeepLinkStore: MHDeepLinkURLSource {
    /// Consumes and clears the latest pending URL.
    public func consumeLatestURL() async -> URL? { // swiftlint:disable:this async_without_await
        consumeLatest()
    }
}

public extension MHDeepLinkStore {
    /// Builds a URL for the route, stores it, and returns the stored URL.
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

private extension MHDeepLinkStore {
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
