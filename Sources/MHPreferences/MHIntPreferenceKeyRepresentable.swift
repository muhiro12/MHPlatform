/// A type that exposes a typed integer preference key for `AppStorage`.
public protocol MHIntPreferenceKeyRepresentable {
    /// Creates the typed integer preference key using the supplied default value.
    func preferenceKey(default defaultValue: Int) -> MHIntPreferenceKey
}
