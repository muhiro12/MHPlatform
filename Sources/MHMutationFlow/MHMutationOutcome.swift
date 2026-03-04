/// Result of a mutation flow execution.
public enum MHMutationOutcome<Value> {
    /// Mutation and all required steps succeeded.
    case succeeded(
            value: Value,
            attempts: Int,
            completedSteps: [String]
         )

    /// Mutation or a post-success step failed.
    case failed(
            error: any Error,
            attempts: Int,
            completedSteps: [String]
         )

    /// Execution stopped because cancellation was requested.
    case cancelled(
            attempts: Int,
            completedSteps: [String]
         )
}
