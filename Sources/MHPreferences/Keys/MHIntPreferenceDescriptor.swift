/// A typed descriptor for integer preferences.
public struct MHIntPreferenceDescriptor: Hashable, MHPreferenceDescriptorProtocol, Sendable {
    /// The value type associated with this descriptor.
    public typealias Value = Int

    /// Persistent storage key name used by `UserDefaults`.
    public let storageKey: String

    /// The default defaults selection used when no explicit store is injected.
    public let defaultSelection: MHUserDefaultsSelection

    /// The default value returned when the descriptor is not set.
    public let defaultValue: Int

    /// Creates an integer preference descriptor with an optional default value.
    public init(
        storageKey: String,
        defaultSelection: MHUserDefaultsSelection,
        default defaultValue: Int = .zero
    ) {
        precondition(storageKey.isEmpty == false)
        self.storageKey = storageKey
        self.defaultSelection = defaultSelection
        self.defaultValue = defaultValue
    }
}
