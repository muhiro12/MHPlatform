/// The result of pruning unknown keys from a `UserDefaults` domain.
public struct MHUserDefaultsCleanupReport: Equatable, Sendable {
    /// Whether cleanup executed against the requested domain.
    public let didRun: Bool

    /// Sorted storage keys removed from the requested domain.
    public let removedStorageKeys: [String]

    /// Creates a cleanup report.
    public init(
        removedStorageKeys: [String],
        didRun: Bool = true
    ) {
        self.didRun = didRun
        self.removedStorageKeys = removedStorageKeys
    }
}
