import Foundation

/// Ordered deep-link source chain that consumes from the first source with a
/// pending URL.
public struct MHDeepLinkSourceChain: Sendable {
    private let sources: [any MHDeepLinkURLSource]

    /// Creates a chain from an ordered variadic source list.
    public init(_ sources: any MHDeepLinkURLSource...) {
        self.sources = sources
    }

    /// Creates a chain from an ordered source array.
    public init(_ sources: [any MHDeepLinkURLSource]) {
        self.sources = sources
    }

    /// Consumes the first available pending URL from the ordered source list.
    public func consumeLatestURL() async -> URL? {
        for source in sources {
            if let url = await source.consumeLatestURL() {
                return url
            }
        }

        return nil
    }

    /// Forwards the first available pending URL into a destination.
    @discardableResult
    public func forwardLatestURL(
        to destination: some MHDeepLinkURLDestination
    ) async -> URL? {
        guard let url = await consumeLatestURL() else {
            return nil
        }

        await destination.setPendingURL(url)
        return url
    }
}

extension MHDeepLinkSourceChain: MHDeepLinkURLSource {}
