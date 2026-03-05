/// A typed key for optional string preferences.
public struct MHStringPreferenceKey: Hashable, MHPreferenceKeyProtocol, Sendable {
    /// The value type associated with this key.
    public typealias Value = String?

    /// The raw storage key name used by `UserDefaults`.
    public let name: String

    /// Creates an optional-string preference key.
    public init(_ name: String) {
        self.name = name
    }
}
