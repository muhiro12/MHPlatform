import MHPreferences

/// A caller-owned storage key for logging snapshots.
public struct MHLogSnapshotStorageKey: Hashable, MHStorageKeyProtocol, Sendable {
    /// Persistent storage key name used by `UserDefaults`.
    public let storageKey: String

    /// Creates a logging snapshot storage key.
    public init(storageKey: String) {
        precondition(storageKey.isEmpty == false)
        self.storageKey = storageKey
    }
}
