import Foundation
import MHDeepLinking

/// Test helper that records pending deep-link URLs while supporting both
/// consume-once source and destination contracts.
public actor MHDeepLinkURLRecorder: MHDeepLinkURLSource, MHDeepLinkURLDestination {
    private var pendingURL: URL?
    private var consumeCount = 0
    private var pendingURLHistory = [URL?]()

    public init(initialURL: URL? = nil) {
        self.pendingURL = initialURL
    }

    public func setPendingURL(_ url: URL?) async {
        await Task.yield()
        pendingURL = url
        pendingURLHistory.append(url)
    }

    public func consumeLatestURL() async -> URL? {
        await Task.yield()
        consumeCount += 1
        defer {
            pendingURL = nil
        }
        return pendingURL
    }

    public func latestURL() -> URL? {
        pendingURL
    }

    public func consumeCountValue() -> Int {
        consumeCount
    }

    public func pendingURLHistoryValue() -> [URL?] {
        pendingURLHistory
    }
}
