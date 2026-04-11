/// A typed key for boolean preferences.
public struct MHBoolPreferenceKey: Hashable, MHPreferenceKeyProtocol, Sendable {
    /// The value type associated with this key.
    public typealias Value = Bool

    /// Persistent storage key name used by `UserDefaults`.
    public let storageKey: String

    /// The default value returned when the key is not set.
    public let defaultValue: Bool

    /// Creates a boolean preference key with an optional default value.
    public init(
        storageKey: String,
        default defaultValue: Bool = false
    ) {
        precondition(storageKey.isEmpty == false)
        self.storageKey = storageKey
        self.defaultValue = defaultValue
    }
}
