/// A type that exposes a typed string preference key for `AppStorage`.
public protocol MHStringPreferenceKeyRepresentable {
    /// The typed string preference key used for storage.
    var preferenceKey: MHStringPreferenceKey { get }
}
