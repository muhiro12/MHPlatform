import Foundation

/// UserDefaults-backed pending deep-link storage.
public final class MHDeepLinkStore {
    private let userDefaults: UserDefaults
    private let key: String

    /// Creates a persistent deep-link store.
    public init(
        userDefaults: UserDefaults,
        key: String
    ) {
        self.userDefaults = userDefaults
        self.key = key
    }

    /// Persists a pending URL.
    public func ingest(_ url: URL) {
        userDefaults.set(url.absoluteString, forKey: key)
    }

    /// Consumes and clears the latest pending URL.
    public func consumeLatest() -> URL? {
        defer {
            userDefaults.removeObject(forKey: key)
        }

        guard let urlString = userDefaults.string(forKey: key) else {
            return nil
        }
        return URL(string: urlString)
    }
}
