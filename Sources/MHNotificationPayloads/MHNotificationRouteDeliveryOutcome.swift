import Foundation

/// Describes how notification route delivery selected a pending URL.
public struct MHNotificationRouteDeliveryOutcome: Equatable, Sendable {
    public enum Source: Equatable, Sendable {
        case payload
        case fallback
        case noRoute
    }

    public let routeURL: URL?
    public let source: Source

    public init(
        routeURL: URL?,
        source: Source
    ) {
        self.routeURL = routeURL
        self.source = source
    }
}
