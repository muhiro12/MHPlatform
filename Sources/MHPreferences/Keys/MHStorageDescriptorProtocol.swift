/// A caller-owned storage descriptor backed by `UserDefaults`.
public protocol MHStorageDescriptorProtocol {
    /// Fully composed storage key name used by `UserDefaults`.
    var storageKey: String { get }

    /// The default defaults selection used when no explicit store is injected.
    var defaultSelection: MHUserDefaultsSelection { get }
}
