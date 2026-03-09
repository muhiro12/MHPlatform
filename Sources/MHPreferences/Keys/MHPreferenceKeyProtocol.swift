/// A typed preference key namespace used by ``MHPreferenceStore``.
public protocol MHPreferenceKeyProtocol {
    /// The value type associated with this preference key.
    associatedtype Value

    /// Namespace segment used for collision-safe key composition.
    var namespace: String { get }

    /// Key name segment within the namespace.
    var name: String { get }

    /// Fully composed storage key name used by `UserDefaults`.
    var storageKey: String { get }
}

public extension MHPreferenceKeyProtocol {
    /// Fully-qualified key used for persistent storage.
    var storageKey: String {
        "\(namespace).\(name)"
    }
}
