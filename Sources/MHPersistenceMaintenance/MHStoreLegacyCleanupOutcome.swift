/// Outcome of a legacy store cleanup attempt.
public enum MHStoreLegacyCleanupOutcome: Sendable, Equatable {
    /// Legacy files were removed.
    case removed(fileNames: [String])

    /// Cleanup was skipped.
    case skipped(MHStoreMigrationSkipReason)
}
