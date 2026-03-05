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
