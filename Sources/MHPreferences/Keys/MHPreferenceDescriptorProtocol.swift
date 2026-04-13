/// A typed preference descriptor used by ``MHPreferenceStore`` and SwiftUI wrappers.
public protocol MHPreferenceDescriptorProtocol: MHStorageDescriptorProtocol {
    /// The value type associated with this preference descriptor.
    associatedtype Value

    /// Legacy storage slots that should migrate into this descriptor.
    var legacySources: [MHLegacyStorageReference] { get }
}
