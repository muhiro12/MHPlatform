import Foundation

/// In-memory pending route inbox that is safe to use across concurrent tasks.
public actor MHDeepLinkInbox {
    private var pendingURL: URL?

    /// Creates an empty inbox.
    public init() {
        // Intentionally empty.
    }

    /// Stores a pending URL and replaces any previous one.
    public func store(_ url: URL) {
        pendingURL = url
    }

    /// Consumes and clears the pending URL.
    public func consume() -> URL? {
        let currentURL = pendingURL
        pendingURL = nil
        return currentURL
    }
}
