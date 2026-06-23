import Foundation

/// Policy controlling whether and when an in-app review request should be attempted.
public struct MHReviewPolicy: Sendable {
    private enum Constants {
        static let defaultRequestDelaySeconds = 2
    }

    /// Upper bound of the lottery range used for deciding review requests.
    public let lotteryMaxExclusive: Int

    /// Delay applied before attempting the review request.
    public let requestDelay: Duration

    /// Creates a review request policy with the default request delay.
    public init(
        lotteryMaxExclusive: Int
    ) {
        self.init(
            lotteryMaxExclusive: lotteryMaxExclusive,
            requestDelay: .seconds(Constants.defaultRequestDelaySeconds)
        )
    }

    /// Creates a review request policy.
    public init(
        lotteryMaxExclusive: Int,
        requestDelay: Duration
    ) {
        self.lotteryMaxExclusive = lotteryMaxExclusive
        self.requestDelay = requestDelay
    }

    /// Returns whether a review should be requested for the provided lottery value.
    public func shouldRequestReview(randomValue: Int) -> Bool {
        guard lotteryMaxExclusive > 0 else {
            return false
        }
        return randomValue == .zero
    }
}
