/// A typed preference key namespace used by ``MHPreferenceStore``.
public protocol MHPreferenceKeyProtocol {
    /// The value type associated with this preference key.
    associatedtype Value

    /// The raw storage key name used by `UserDefaults`.
    var name: String { get }
}
