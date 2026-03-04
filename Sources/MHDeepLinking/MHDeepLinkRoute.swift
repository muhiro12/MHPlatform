/// Converts between app-defined route values and deep-link descriptors.
public protocol MHDeepLinkRoute {
    /// Returns the descriptor used to build a deep-link URL.
    var deepLinkDescriptor: MHDeepLinkDescriptor { get }

    /// Creates a route from a parsed deep-link descriptor.
    init?(deepLinkDescriptor: MHDeepLinkDescriptor)
}
