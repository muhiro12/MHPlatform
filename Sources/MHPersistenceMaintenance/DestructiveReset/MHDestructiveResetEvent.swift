/// Event emitted while destructive reset steps are running.
public enum MHDestructiveResetEvent: Sendable {
    /// A step started.
    case stepStarted(name: String)

    /// A step succeeded.
    case stepSucceeded(name: String)

    /// A step failed.
    case stepFailed(
            name: String,
            message: String
         )

    /// All steps completed successfully.
    case completed
}
