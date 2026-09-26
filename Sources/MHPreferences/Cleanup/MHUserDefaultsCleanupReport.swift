/// The result of pruning unknown keys from a `UserDefaults` domain.
public struct MHUserDefaultsCleanupReport: Equatable, Sendable {
    /// Whether cleanup executed against the requested domain.
    public let didRun: Bool

    /// Sorted, unique keys in the caller's allowlist, including keys not yet stored.
    public let knownStorageKeys: [String]

    /// Sorted keys removed because they were absent from `knownStorageKeys`.
    public let removedStorageKeys: [String]

    /// Creates a cleanup report.
    public init(
        removedStorageKeys: [String],
        didRun: Bool = true,
        knownStorageKeys: [String] = []
    ) {
        self.didRun = didRun
        self.removedStorageKeys = removedStorageKeys
        self.knownStorageKeys = Array(Set(knownStorageKeys)).sorted()
    }
}
