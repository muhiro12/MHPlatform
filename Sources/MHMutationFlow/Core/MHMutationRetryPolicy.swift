import Foundation

/// Retry policy for mutation operations.
public struct MHMutationRetryPolicy: Sendable {
    private enum Constants {
        static let noRetryMaximumAttempts = 1
        static let defaultMaximumAttempts = 3
        static let defaultBackoffMilliseconds = 200
    }

    /// Retry policy with no retry.
    public static let noRetry = Self(
        maximumAttempts: Constants.noRetryMaximumAttempts,
        backoff: .immediate
    )

    /// Default retry policy used by examples.
    public static let `default` = Self(
        maximumAttempts: Constants.defaultMaximumAttempts,
        backoff: .fixed(.milliseconds(Constants.defaultBackoffMilliseconds))
    )

    /// Maximum attempts, including the first attempt.
    public let maximumAttempts: Int

    /// Backoff strategy between failed attempts.
    public let backoff: MHMutationBackoff

    /// Creates a retry policy.
    public init(
        maximumAttempts: Int,
        backoff: MHMutationBackoff
    ) {
        self.maximumAttempts = max(maximumAttempts, 1)
        self.backoff = backoff
    }
}
