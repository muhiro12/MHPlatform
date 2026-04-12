/// A caller-owned reference to a legacy `UserDefaults` storage slot.
public struct MHLegacyStorageReference: Hashable, Sendable {
    /// Fully composed legacy storage key name used by `UserDefaults`.
    public let storageKey: String

    /// The legacy defaults selection that currently owns the value.
    public let selection: MHUserDefaultsSelection

    /// Creates a legacy storage reference.
    public init(
        storageKey: String,
        selection: MHUserDefaultsSelection
    ) {
        precondition(storageKey.isEmpty == false)
        self.storageKey = storageKey
        self.selection = selection
    }
}
