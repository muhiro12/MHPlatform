/// A typed key for boolean preferences.
public struct MHBoolPreferenceKey: Hashable, MHPreferenceKeyProtocol, Sendable {
    /// The value type associated with this key.
    public typealias Value = Bool

    /// Fully composed storage key name used by `UserDefaults`.
    public let storageKey: String

    /// Namespace segment used for collision-safe key composition.
    public let namespace: String

    /// Key name segment within the namespace.
    public let name: String

    /// The default value returned when the key is not set.
    public let defaultValue: Bool

    /// Creates a boolean preference key with an optional default value.
    public init(
        namespace: String,
        name: String,
        default defaultValue: Bool = false
    ) {
        precondition(namespace.isEmpty == false)
        precondition(name.isEmpty == false)
        storageKey = "\(namespace).\(name)"
        self.namespace = namespace
        self.name = name
        self.defaultValue = defaultValue
    }

    /// Creates a boolean preference key using an explicit storage key.
    public init(
        storageKey: String,
        default defaultValue: Bool = false
    ) {
        precondition(storageKey.isEmpty == false)
        self.storageKey = storageKey
        namespace = storageKey
        name = storageKey
        self.defaultValue = defaultValue
    }
}
