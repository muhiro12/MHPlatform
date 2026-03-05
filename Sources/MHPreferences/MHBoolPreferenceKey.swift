/// A typed key for boolean preferences.
public struct MHBoolPreferenceKey: Hashable, MHPreferenceKeyProtocol, Sendable {
    /// The value type associated with this key.
    public typealias Value = Bool

    /// The raw storage key name used by `UserDefaults`.
    public let name: String

    /// The default value returned when the key is not set.
    public let defaultValue: Bool

    /// Creates a boolean preference key with an optional default value.
    public init(
        _ name: String,
        default defaultValue: Bool = false
    ) {
        self.name = name
        self.defaultValue = defaultValue
    }
}
