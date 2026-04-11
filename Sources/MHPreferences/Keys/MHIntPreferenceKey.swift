/// A typed key for integer preferences.
public struct MHIntPreferenceKey: Hashable, MHPreferenceKeyProtocol, Sendable {
    /// The value type associated with this key.
    public typealias Value = Int

    /// Persistent storage key name used by `UserDefaults`.
    public let storageKey: String

    /// The default value returned when the key is not set.
    public let defaultValue: Int

    /// Creates an integer preference key with an optional default value.
    public init(
        storageKey: String,
        default defaultValue: Int = .zero
    ) {
        precondition(storageKey.isEmpty == false)
        self.storageKey = storageKey
        self.defaultValue = defaultValue
    }
}
