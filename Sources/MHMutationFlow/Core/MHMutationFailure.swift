/// Failure vocabulary for mutation orchestration.
public enum MHMutationFailure: Sendable {
    /// Mutation operation failed.
    case operation(errorDescription: String)

    /// Post-success step failed.
    case step(name: String, errorDescription: String)
}
