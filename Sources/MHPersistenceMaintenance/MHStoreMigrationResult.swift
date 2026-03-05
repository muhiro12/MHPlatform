/// Outcome of a store migration attempt.
public enum MHStoreMigrationResult: Sendable, Equatable {
    /// Migration copied files into the current location.
    case migrated(
            copiedFileNames: [String],
            removedCurrentFileNames: [String]
         )

    /// Migration was skipped.
    case skipped(MHStoreMigrationSkipReason)
}
