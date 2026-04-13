/// Outcome of a store relocation attempt.
public enum MHStoreRelocationOutcome: Sendable, Equatable {
    /// Relocation copied files into the current location.
    case relocated(
            copiedFileNames: [String],
            removedCurrentFileNames: [String]
         )

    /// Relocation was skipped.
    case skipped(MHStoreRelocationSkipReason)
}
