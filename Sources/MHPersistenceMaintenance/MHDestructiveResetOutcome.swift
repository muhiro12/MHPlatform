/// Outcome of running destructive reset steps.
public enum MHDestructiveResetOutcome: Sendable {
    /// All steps succeeded.
    case succeeded(completedSteps: [String])

    /// A step failed and execution stopped.
    case failed(
            error: any Error & Sendable,
            failedStep: String,
            completedSteps: [String]
         )
}
