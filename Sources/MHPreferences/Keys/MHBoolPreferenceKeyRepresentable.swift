/// A type that exposes a typed boolean preference key for `AppStorage`.
public protocol MHBoolPreferenceKeyRepresentable {
    /// The typed boolean preference key used for storage.
    var preferenceKey: MHBoolPreferenceKey { get }
}
