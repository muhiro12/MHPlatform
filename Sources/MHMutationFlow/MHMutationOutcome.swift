/// Terminal outcome of a mutation flow execution.
public enum MHMutationOutcome<Value: Sendable>: Sendable {
    /// Mutation and all required steps succeeded.
    case succeeded(
            value: Value,
            attempts: Int,
            completedSteps: [String]
         )

    /// Mutation or a post-success step failed.
    case failed(
            failure: MHMutationFailure,
            attempts: Int,
            completedSteps: [String],
            isRecoverable: Bool
         )

    /// Execution stopped because cancellation was requested.
    case cancelled(
            attempts: Int,
            completedSteps: [String]
         )
}
