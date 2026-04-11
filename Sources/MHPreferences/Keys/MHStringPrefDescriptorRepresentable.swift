/// A type that exposes a typed string preference descriptor for `AppStorage`.
public protocol MHStringPrefDescriptorRepresentable {
    /// The typed string preference descriptor used for storage.
    var preferenceDescriptor: MHStringPreferenceDescriptor { get }
}
