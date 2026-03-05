/// A typed key for optional string preferences.
public struct MHStringPreferenceKey: Hashable, MHPreferenceKeyProtocol, Sendable {
    /// The value type associated with this key.
    public typealias Value = String?

    /// Namespace segment used for collision-safe key composition.
    public let namespace: String

    /// Key name segment within the namespace.
    public let name: String

    /// Creates an optional-string preference key.
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
