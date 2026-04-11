/// A typed descriptor for optional string preferences.
public struct MHStringPreferenceDescriptor: Hashable, MHPreferenceDescriptorProtocol, Sendable {
    /// The value type associated with this descriptor.
    public typealias Value = String?

    /// Persistent storage key name used by `UserDefaults`.
    public let storageKey: String

    /// The default defaults selection used when no explicit store is injected.
    public let defaultSelection: MHUserDefaultsSelection

    /// Creates an optional-string preference descriptor.
    public init(
        storageKey: String,
        defaultSelection: MHUserDefaultsSelection
    ) {
        precondition(storageKey.isEmpty == false)
        self.storageKey = storageKey
        self.defaultSelection = defaultSelection
    }
}
