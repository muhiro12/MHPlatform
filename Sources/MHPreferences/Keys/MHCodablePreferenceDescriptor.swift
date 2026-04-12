import Foundation

/// A typed descriptor for `Codable` values persisted in `Data` form.
public struct MHCodablePreferenceDescriptor<StoredValue: Codable & Sendable>:
    Hashable,
    MHPreferenceDescriptorProtocol,
    Sendable {
    /// The value type associated with this descriptor.
    public typealias Value = StoredValue

    /// Persistent storage key name used by `UserDefaults`.
    public let storageKey: String

    /// The default defaults selection used when no explicit store is injected.
    public let defaultSelection: MHUserDefaultsSelection

    /// Legacy storage slots that should migrate into this descriptor.
    public let legacySources: [MHLegacyStorageReference]

    /// Creates a codable preference descriptor.
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
