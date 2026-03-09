/// A typed key for integer preferences.
public struct MHIntPreferenceKey: Hashable, MHPreferenceKeyProtocol, Sendable {
    /// The value type associated with this key.
    public typealias Value = Int

    /// Fully composed storage key name used by `UserDefaults`.
    public let storageKey: String

    /// Namespace segment used for collision-safe key composition.
    public let namespace: String

    /// Key name segment within the namespace.
    public let name: String

    /// The default value returned when the key is not set.
    public let defaultValue: Int

    /// Creates an integer preference key with an optional default value.
    public init(
        namespace: String,
        name: String,
        default defaultValue: Int = .zero
    ) {
        precondition(namespace.isEmpty == false)
        precondition(name.isEmpty == false)
        storageKey = "\(namespace).\(name)"
        self.namespace = namespace
        self.name = name
        self.defaultValue = defaultValue
    }

    /// Creates an integer preference key using an explicit storage key.
    public init(
        storageKey: String,
        default defaultValue: Int = .zero
    ) {
        precondition(storageKey.isEmpty == false)
        self.storageKey = storageKey
        namespace = storageKey
        name = storageKey
        self.defaultValue = defaultValue
    }
}
