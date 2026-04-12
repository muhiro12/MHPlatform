/// Outcome of running preference-migration steps.
public enum MHPreferenceMigrationOutcome: Sendable {
    /// All eligible steps completed successfully.
    case succeeded(
        completedStepIDs: [String],
        skippedStepIDs: [String]
    )

    /// A step failed and stopped the migration run.
    case failed(
        error: any Error & Sendable,
        failedStepID: String,
        completedStepIDs: [String],
        skippedStepIDs: [String]
    )
}
