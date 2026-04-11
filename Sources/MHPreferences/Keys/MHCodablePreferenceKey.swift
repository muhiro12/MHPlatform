import Foundation

/// A typed key for `Codable` values persisted in `Data` form.
public struct MHCodablePreferenceKey<StoredValue: Codable & Sendable>: Hashable, MHPreferenceKeyProtocol, Sendable {
    /// The value type associated with this key.
    public typealias Value = StoredValue

    /// Persistent storage key name used by `UserDefaults`.
    public let storageKey: String

    /// Creates a codable preference key.
    public init(storageKey: String) {
        precondition(storageKey.isEmpty == false)
        self.storageKey = storageKey
    }
}
