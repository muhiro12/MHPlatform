/// A typed key for integer preferences.
public struct MHIntPreferenceKey: Hashable, MHPreferenceKeyProtocol, Sendable {
    /// The value type associated with this key.
    public typealias Value = Int

    /// The raw storage key name used by `UserDefaults`.
    public let name: String

    /// The default value returned when the key is not set.
    public let defaultValue: Int

    /// Creates an integer preference key with an optional default value.
    public init(
        _ name: String,
        default defaultValue: Int = .zero
    ) {
        self.name = name
        self.defaultValue = defaultValue
    }
}
