import MHReviewPolicy
import Testing

struct MHReviewPolicyTests {
    @Test
    func shouldRequestReview_returns_true_for_zero_with_valid_range() {
        let policy = MHReviewPolicy(lotteryMaxExclusive: 5)

        #expect(policy.shouldRequestReview(randomValue: 0) == true)
    }

    @Test
    func shouldRequestReview_returns_false_for_non_zero() {
        let policy = MHReviewPolicy(lotteryMaxExclusive: 5)

        #expect(policy.shouldRequestReview(randomValue: 1) == false)
    }

    @Test
    func shouldRequestReview_returns_false_for_invalid_lottery_range() {
        let policy = MHReviewPolicy(lotteryMaxExclusive: 0)

        #expect(policy.shouldRequestReview(randomValue: 0) == false)
    }
}
