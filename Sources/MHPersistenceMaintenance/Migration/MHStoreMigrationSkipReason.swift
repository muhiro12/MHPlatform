/// Reason why store migration or legacy cleanup was skipped.
public enum MHStoreMigrationSkipReason: Sendable, Equatable {
    /// Legacy and current store URLs are the same location.
    case sameLocation

    /// Legacy store file does not exist.
    case missingLegacyStore
}
