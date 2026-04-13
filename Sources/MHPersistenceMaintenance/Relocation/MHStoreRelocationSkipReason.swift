/// Reason why store relocation or legacy cleanup was skipped.
public enum MHStoreRelocationSkipReason: Sendable, Equatable {
    /// Legacy and current store URLs are the same location.
    case sameLocation

    /// Legacy store file does not exist.
    case missingLegacyStore
}
