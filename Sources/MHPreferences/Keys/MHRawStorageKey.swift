/// A raw caller-owned storage key backed by `UserDefaults`.
public struct MHRawStorageKey: Hashable, MHStorageKeyProtocol, Sendable {
    /// Fully composed storage key name used by `UserDefaults`.
    public let storageKey: String

    /// Creates a raw storage key.
    public init(storageKey: String) {
        precondition(storageKey.isEmpty == false)
        self.storageKey = storageKey
    }
}
