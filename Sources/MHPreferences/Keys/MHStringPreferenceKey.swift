/// A typed key for optional string preferences.
public struct MHStringPreferenceKey: Hashable, MHPreferenceKeyProtocol, Sendable {
    /// The value type associated with this key.
    public typealias Value = String?

    /// Persistent storage key name used by `UserDefaults`.
    public let storageKey: String

    /// Creates an optional-string preference key.
    public init(storageKey: String) {
        precondition(storageKey.isEmpty == false)
        self.storageKey = storageKey
    }
}
