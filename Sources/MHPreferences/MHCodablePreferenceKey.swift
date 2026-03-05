import Foundation

/// A typed key for `Codable` values persisted in `Data` form.
public struct MHCodablePreferenceKey<StoredValue: Codable & Sendable>: Hashable, MHPreferenceKeyProtocol, Sendable {
    /// The value type associated with this key.
    public typealias Value = StoredValue

    /// The raw storage key name used by `UserDefaults`.
    public let name: String

    /// Creates a codable preference key.
    public init(_ name: String) {
        self.name = name
    }
}
