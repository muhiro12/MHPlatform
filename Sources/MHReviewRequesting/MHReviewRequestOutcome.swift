/// Result of a review request attempt.
public enum MHReviewRequestOutcome: Sendable, Equatable {
    /// The request API was invoked.
    case requested

    /// The lottery decision did not request a review.
    case skippedByPolicy

    /// The policy has an invalid lottery range (`<= 0`).
    case skippedInvalidLotteryRange

    /// No foreground scene was available for requesting a review.
    case skippedNoForegroundScene

    /// The current platform does not support the live requester implementation.
    case unsupportedPlatform
}
