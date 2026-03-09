import Foundation

/// Progress details emitted by a running mutation.
public enum MHMutationProgress: Sendable {
    /// A retry was scheduled after an operation failure.
    case retryScheduled(nextAttempt: Int, delay: Duration)

    /// A post-success step started.
    case stepStarted(name: String, completedSteps: Int, totalSteps: Int)

    /// A post-success step succeeded.
    case stepSucceeded(name: String, completedSteps: Int, totalSteps: Int)
}
