/// Caller-owned storage descriptors for current and previous logging snapshots.
public struct MHLogSnapshotStorageDescriptors: Hashable, Sendable {
    /// Storage descriptor used for the current session snapshot.
    public let current: MHLogSnapshotStorageDescriptor

    /// Storage descriptor used for the previous session snapshot.
    public let previous: MHLogSnapshotStorageDescriptor

    /// Creates the storage-descriptor bundle used by ``MHLoggingBootstrap``.
    public init(
        current: MHLogSnapshotStorageDescriptor,
        previous: MHLogSnapshotStorageDescriptor
    ) {
        precondition(current.storageKey != previous.storageKey)
        self.current = current
        self.previous = previous
    }
}
