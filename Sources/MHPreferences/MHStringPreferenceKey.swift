/// A typed key for optional string preferences.
public struct MHStringPreferenceKey: Hashable, MHPreferenceKeyProtocol, Sendable {
    /// The value type associated with this key.
    public typealias Value = String?

    /// Fully composed storage key name used by `UserDefaults`.
    public let storageKey: String

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
        storageKey = "\(namespace).\(name)"
        self.namespace = namespace
        self.name = name
    }

    /// Creates an optional-string preference key using an explicit storage key.
    public init(storageKey: String) {
        precondition(storageKey.isEmpty == false)
        self.storageKey = storageKey
        namespace = storageKey
        name = storageKey
    }
}
