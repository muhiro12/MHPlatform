/// A type that exposes a typed boolean preference descriptor for `AppStorage`.
public protocol MHBoolPrefDescriptorRepresentable {
    /// The typed boolean preference descriptor used for storage.
    var preferenceDescriptor: MHBoolPreferenceDescriptor { get }
}
