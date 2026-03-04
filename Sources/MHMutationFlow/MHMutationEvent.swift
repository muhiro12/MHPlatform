/// Events emitted while running a mutation flow.
public enum MHMutationEvent: Sendable {
    /// A mutation attempt started.
    case attemptStarted(Int)

    /// A mutation attempt failed with a message.
    case attemptFailed(Int, String)

    /// A mutation attempt succeeded.
    case attemptSucceeded(Int)

    /// A post-success step started.
    case stepStarted(String)

    /// A post-success step succeeded.
    case stepSucceeded(String)

    /// A post-success step failed with a message.
    case stepFailed(String, String)

    /// Execution was cancelled.
    case cancelled
}
