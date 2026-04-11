/// A type that exposes a typed integer preference descriptor for `AppStorage`.
public protocol MHIntPrefDescriptorRepresentable {
    /// Creates the typed integer preference descriptor using the supplied default value.
    func preferenceDescriptor(default defaultValue: Int) -> MHIntPreferenceDescriptor
}
