import Foundation

/// Policy controlling whether and when an in-app review request should be attempted.
public struct MHReviewPolicy: Sendable {
    /// Upper bound of the lottery range used for deciding review requests.
    public let lotteryMaxExclusive: Int

    /// Delay applied before attempting the review request.
    public let requestDelay: Duration

    /// Creates a review request policy.
    public init(
        lotteryMaxExclusive: Int,
        // swiftlint:disable:next no_magic_numbers
        requestDelay: Duration = .seconds(2)
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
