/// A typed preference key used by ``MHPreferenceStore``.
public protocol MHPreferenceKeyProtocol: MHStorageKeyProtocol {
    /// The value type associated with this preference key.
    associatedtype Value
}
