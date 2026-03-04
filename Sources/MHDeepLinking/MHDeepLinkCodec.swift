import Foundation

/// Builds and parses deep-link URLs for an app-defined route type.
public struct MHDeepLinkCodec<Route: MHDeepLinkRoute>: Sendable {
    /// URL grammar configuration for this codec.
    public let configuration: MHDeepLinkConfiguration

    private var normalizedAllowedUniversalLinkHosts: Set<String> {
        Set(
            configuration.allowedUniversalLinkHosts.map { host in
                host.lowercased()
            }
        )
    }

    /// Creates a codec with the given configuration.
    public init(configuration: MHDeepLinkConfiguration) {
        self.configuration = configuration
    }

    /// Builds a URL for the supplied route and transport.
    public func url(
        for route: Route,
        transport: MHDeepLinkTransport
    ) -> URL? {
        let descriptor = route.deepLinkDescriptor

        switch transport {
        case .customScheme:
            return customSchemeURL(for: descriptor)
        case .universalLink:
            return universalLinkURL(for: descriptor)
        }
    }

    /// Builds a URL using the preferred transport, then falls back to the alternate one.
    public func preferredURL(for route: Route) -> URL? {
        if let preferredURL = url(
            for: route,
            transport: configuration.preferredTransport
        ) {
            return preferredURL
        }

        return url(
            for: route,
            transport: alternateTransport(for: configuration.preferredTransport)
        )
    }

    /// Parses a deep-link URL into the app-defined route.
    public func parse(_ url: URL) -> Route? {
        guard let scheme = url.scheme?.lowercased() else {
            return nil
        }

        let parsedPathComponents: [String]
        switch scheme {
        case "http", "https":
            guard let host = url.host?.lowercased(),
                  normalizedAllowedUniversalLinkHosts.contains(host) else {
                return nil
            }
            parsedPathComponents = normalizedUniversalLinkPathComponents(from: url)
        case configuration.customScheme.lowercased():
            parsedPathComponents = normalizedCustomSchemePathComponents(from: url)
        default:
            return nil
        }

        let queryItems = URLComponents(
            url: url,
            resolvingAgainstBaseURL: false
        )?.queryItems ?? []

        return .init(
            deepLinkDescriptor: .init(
                pathComponents: parsedPathComponents,
                queryItems: queryItems
            )
        )
    }

    private func customSchemeURL(for descriptor: MHDeepLinkDescriptor) -> URL? {
        guard configuration.customScheme.isEmpty == false else {
            return nil
        }

        var components = URLComponents()
        components.scheme = configuration.customScheme
        components.queryItems = descriptor.queryItems.isEmpty ? nil : descriptor.queryItems

        if let firstPathComponent = descriptor.pathComponents.first {
            components.host = firstPathComponent
        }

        let remainingPathComponents = descriptor.pathComponents.dropFirst()
        if remainingPathComponents.isEmpty == false {
            components.path = "/" + remainingPathComponents.joined(separator: "/")
        }

        if let builtURL = components.url {
            return builtURL
        }

        guard descriptor.pathComponents.isEmpty else {
            return nil
        }

        guard let baseURL = URL(string: "\(configuration.customScheme)://") else {
            return nil
        }

        guard descriptor.queryItems.isEmpty == false else {
            return baseURL
        }

        var queryComponents = URLComponents(
            url: baseURL,
            resolvingAgainstBaseURL: false
        )
        queryComponents?.queryItems = descriptor.queryItems
        return queryComponents?.url
    }

    private func universalLinkURL(for descriptor: MHDeepLinkDescriptor) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = configuration.preferredUniversalLinkHost
        components.queryItems = descriptor.queryItems.isEmpty ? nil : descriptor.queryItems

        var universalPathComponents = [String]()
        if configuration.universalLinkPathPrefix.isEmpty == false {
            universalPathComponents.append(configuration.universalLinkPathPrefix)
        }
        universalPathComponents.append(contentsOf: descriptor.pathComponents)
        components.path = "/" + universalPathComponents.joined(separator: "/")

        return components.url
    }

    private func normalizedCustomSchemePathComponents(from url: URL) -> [String] {
        var pathComponents = [String]()

        if let host = url.host, host.isEmpty == false {
            pathComponents.append(host)
        }
        pathComponents.append(contentsOf: normalizedPathComponents(from: url.pathComponents))
        return pathComponents
    }

    private func normalizedUniversalLinkPathComponents(from url: URL) -> [String] {
        var pathComponents = normalizedPathComponents(from: url.pathComponents)

        if let firstPathComponent = pathComponents.first,
           firstPathComponent.caseInsensitiveCompare(
            configuration.universalLinkPathPrefix
           ) == .orderedSame {
            _ = pathComponents.removeFirst()
        }

        return pathComponents
    }

    private func normalizedPathComponents(from rawPathComponents: [String]) -> [String] {
        rawPathComponents.filter { pathComponent in
            pathComponent != "/" && pathComponent.isEmpty == false
        }
    }

    private func alternateTransport(
        for transport: MHDeepLinkTransport
    ) -> MHDeepLinkTransport {
        switch transport {
        case .customScheme:
            return .universalLink
        case .universalLink:
            return .customScheme
        }
    }
}
