import Foundation

/// A typed key for `Codable` values persisted in `Data` form.
public struct MHCodablePreferenceKey<StoredValue: Codable & Sendable>: Hashable, MHPreferenceKeyProtocol, Sendable {
    /// The value type associated with this key.
    public typealias Value = StoredValue

    /// Fully composed storage key name used by `UserDefaults`.
    public let storageKey: String

    /// Namespace segment used for collision-safe key composition.
    public let namespace: String

    /// Key name segment within the namespace.
    public let name: String

    /// Creates a codable preference key.
    public init(
        namespace: String,
        name: String
    ) {
        precondition(namespace.isEmpty == false)
        precondition(name.isEmpty == false)
        storageKey = "\(namespace).\(name)"
        self.namespace = namespace
        self.name = name
    }

    /// Creates a codable preference key using an explicit storage key.
    public init(storageKey: String) {
        precondition(storageKey.isEmpty == false)
        self.storageKey = storageKey
        namespace = storageKey
        name = storageKey
    }
}
