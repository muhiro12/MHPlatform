/// A caller-owned storage key backed by `UserDefaults`.
public protocol MHStorageKeyProtocol {
    /// Fully composed storage key name used by `UserDefaults`.
    var storageKey: String { get }
}
