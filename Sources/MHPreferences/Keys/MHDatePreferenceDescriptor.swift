import Foundation

/// A typed descriptor for optional date preferences.
public struct MHDatePreferenceDescriptor: Hashable, MHPreferenceDescriptorProtocol, Sendable {
    /// The value type associated with this descriptor.
    public typealias Value = Date?

    /// Persistent storage key name used by `UserDefaults`.
    public let storageKey: String

    /// The default defaults selection used when no explicit store is injected.
    public let defaultSelection: MHUserDefaultsSelection

    /// Legacy storage slots that should migrate into this descriptor.
    public let legacySources: [MHLegacyStorageReference]

    /// Creates an optional-date preference descriptor.
    public init(
        storageKey: String,
        defaultSelection: MHUserDefaultsSelection,
        legacySources: [MHLegacyStorageReference] = []
    ) {
        precondition(storageKey.isEmpty == false)
        self.storageKey = storageKey
        self.defaultSelection = defaultSelection
        self.legacySources = legacySources
    }
}
