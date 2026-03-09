/// Events emitted while running a mutation.
public enum MHMutationEvent<Value: Sendable>: Sendable {
    /// A mutation attempt started.
    case started(mutation: String, attempt: Int)

    /// A mutation progress update was emitted.
    case progress(MHMutationProgress)

    /// Mutation flow completed successfully.
    case succeeded(value: Value, attempts: Int, completedSteps: [String])

    /// Mutation flow reported a failure.
    case failed(
            errorDescription: String,
            attempts: Int,
            completedSteps: [String],
            isRecoverable: Bool
         )

    /// Mutation flow was cancelled.
    case cancelled(attempts: Int, completedSteps: [String])
}
