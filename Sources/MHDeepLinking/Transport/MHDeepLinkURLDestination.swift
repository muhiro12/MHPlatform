import Foundation

/// Pending deep-link destination that replaces the current latest URL.
public protocol MHDeepLinkURLDestination: Sendable {
    /// Stores a pending URL, or clears the destination when `nil` is provided.
    func setPendingURL(_ url: URL?) async
}
