import Foundation

/// A typed key for `Codable` values persisted in `Data` form.
public struct MHCodablePreferenceKey<StoredValue: Codable & Sendable>: Hashable, MHPreferenceKeyProtocol, Sendable {
    /// The value type associated with this key.
    public typealias Value = StoredValue

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
        self.namespace = namespace
        self.name = name
    }
}
