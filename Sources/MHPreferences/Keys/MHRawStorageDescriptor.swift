/// A raw caller-owned storage descriptor backed by `UserDefaults`.
public struct MHRawStorageDescriptor: Hashable, MHStorageDescriptorProtocol, Sendable {
    /// Fully composed storage key name used by `UserDefaults`.
    public let storageKey: String

    /// The default defaults selection used when no explicit store is injected.
    public let defaultSelection: MHUserDefaultsSelection

    /// Creates a raw storage descriptor.
    public init(
        storageKey: String,
        defaultSelection: MHUserDefaultsSelection
    ) {
        precondition(storageKey.isEmpty == false)
        self.storageKey = storageKey
        self.defaultSelection = defaultSelection
    }
}
