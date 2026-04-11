/// A typed preference key used by ``MHPreferenceStore``.
public protocol MHPreferenceKeyProtocol {
    /// The value type associated with this preference key.
    associatedtype Value

    /// Fully composed storage key name used by `UserDefaults`.
    var storageKey: String { get }
}
