/// A typed descriptor for boolean preferences.
public struct MHBoolPreferenceDescriptor: Hashable, MHPreferenceDescriptorProtocol, Sendable {
    /// The value type associated with this descriptor.
    public typealias Value = Bool

    /// Persistent storage key name used by `UserDefaults`.
    public let storageKey: String

    /// The default defaults selection used when no explicit store is injected.
    public let defaultSelection: MHUserDefaultsSelection

    /// Legacy storage slots that should migrate into this descriptor.
    public let legacySources: [MHLegacyStorageReference]

    /// The default value returned when the descriptor is not set.
    public let defaultValue: Bool

    /// Creates a boolean preference descriptor with an optional default value.
    public init(
        storageKey: String,
        defaultSelection: MHUserDefaultsSelection,
        legacySources: [MHLegacyStorageReference] = [],
        default defaultValue: Bool = false
    ) {
        precondition(storageKey.isEmpty == false)
        self.storageKey = storageKey
        self.defaultSelection = defaultSelection
        self.legacySources = legacySources
        self.defaultValue = defaultValue
    }
}
