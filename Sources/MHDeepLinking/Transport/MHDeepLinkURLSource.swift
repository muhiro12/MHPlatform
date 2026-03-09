import Foundation

/// Consume-once source for pending deep-link URLs.
public protocol MHDeepLinkURLSource: Sendable {
    /// Consumes and clears the latest pending URL.
    func consumeLatestURL() async -> URL?
}
