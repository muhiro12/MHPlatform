/// Caller-owned storage keys for current and previous logging snapshots.
public struct MHLogSnapshotStorageKeys: Hashable, Sendable {
    /// Storage key used for the current session snapshot.
    public let current: MHLogSnapshotStorageKey

    /// Storage key used for the previous session snapshot.
    public let previous: MHLogSnapshotStorageKey

    /// Creates the storage-key bundle used by ``MHLoggingBootstrap``.
    public init(
        current: MHLogSnapshotStorageKey,
        previous: MHLogSnapshotStorageKey
    ) {
        precondition(current.storageKey != previous.storageKey)
        self.current = current
        self.previous = previous
    }
}
