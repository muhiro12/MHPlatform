import Foundation

/// Route descriptor that contains normalized path components and query items.
public struct MHDeepLinkDescriptor: Equatable, Sendable {
    /// Normalized path components in route order.
    public let pathComponents: [String]

    /// Query items with duplicate keys preserved in order.
    public let queryItems: [URLQueryItem]

    /// Creates a route descriptor.
    public init(
        pathComponents: [String],
        queryItems: [URLQueryItem] = []
    ) {
        self.pathComponents = pathComponents
        self.queryItems = queryItems
    }
}
