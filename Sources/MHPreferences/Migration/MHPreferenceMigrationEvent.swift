/// Event emitted while preference-migration steps are running.
public enum MHPreferenceMigrationEvent: Equatable, Sendable {
    /// A step is about to execute.
    case stepStarted(id: String)

    /// A step was skipped because its stable identifier was already completed.
    case stepSkipped(id: String)

    /// A step completed successfully.
    case stepSucceeded(id: String)

    /// A step failed and stopped the migration run.
    case stepFailed(id: String, message: String)

    /// All eligible steps completed.
    case completed
}
