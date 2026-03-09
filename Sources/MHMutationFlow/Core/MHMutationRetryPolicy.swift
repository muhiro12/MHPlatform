import Foundation

/// Retry policy for mutation operations.
public struct MHMutationRetryPolicy: Sendable {
    /// Retry policy with no retry.
    public static let none = Self( // swiftlint:disable:this discouraged_none_name
        maximumAttempts: 1,
        backoff: .immediate
    )

    /// Default retry policy used by examples.
    public static let `default` = Self(
        // swiftlint:disable:next no_magic_numbers
        maximumAttempts: 3,
        // swiftlint:disable:next no_magic_numbers
        backoff: .fixed(.milliseconds(200))
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
