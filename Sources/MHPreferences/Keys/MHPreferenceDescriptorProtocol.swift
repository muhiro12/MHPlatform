/// A typed preference descriptor used by ``MHPreferenceStore``.
public protocol MHPreferenceDescriptorProtocol: MHStorageDescriptorProtocol {
    /// The value type associated with this preference descriptor.
    associatedtype Value
}
