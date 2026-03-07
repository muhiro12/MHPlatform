import Foundation
import Observation

/// Main-actor observable deep-link inbox that mirrors the latest pending URL.
@MainActor
@preconcurrency
@Observable
public final class MHObservableDeepLinkInbox {
    /// Latest pending URL mirrored for observation.
    public private(set) var pendingURL: URL?

    private let inbox: MHDeepLinkInbox

    /// Creates an observable wrapper around an in-memory deep-link inbox.
    public init(inbox: MHDeepLinkInbox = MHDeepLinkInbox()) {
        self.inbox = inbox
    }

    /// Ingests a pending URL and replaces any previous one.
    public func ingest(_ url: URL) async {
        await inbox.ingest(url)
        pendingURL = url
    }

    /// Consumes and clears the latest pending URL.
    public func consumeLatest() async -> URL? {
        let currentURL = await inbox.consumeLatest()
        pendingURL = nil
        return currentURL
    }

    /// Clears any pending URL and updates the observable mirror.
    public func clear() async {
        await inbox.clear()
        pendingURL = nil
    }
}
