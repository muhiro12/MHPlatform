import MHPreferences

/// A caller-owned storage descriptor for logging snapshots.
public struct MHLogSnapshotStorageDescriptor: Hashable, MHStorageDescriptorProtocol, Sendable {
    /// Persistent storage key name used by `UserDefaults`.
    public let storageKey: String

    /// The default defaults selection used when no explicit store is injected.
    public let defaultSelection: MHUserDefaultsSelection

    /// Creates a logging snapshot storage descriptor.
    public init(
        storageKey: String,
        defaultSelection: MHUserDefaultsSelection
    ) {
        precondition(storageKey.isEmpty == false)
        self.storageKey = storageKey
        self.defaultSelection = defaultSelection
    }
}
