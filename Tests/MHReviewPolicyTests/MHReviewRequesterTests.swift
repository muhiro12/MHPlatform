@testable import MHReviewPolicy
import Testing

struct MHReviewRequesterTests {
    @Test
    func requestIfNeeded_returns_skipped_invalid_range_without_random_or_sleep() async {
        let state = InvocationState()
        let policy = MHReviewPolicy(
            lotteryMaxExclusive: 0,
            requestDelay: .seconds(2)
        )

        let outcome = await MHReviewRequester.requestIfNeeded(
            policy: policy,
            randomValueProvider: { _ in
                state.recordRandomCall()
                return 0
            },
            sleep: { _ in
                state.recordSleepCall()
            }
        )

        #expect(outcome == .skippedInvalidLotteryRange)
        #expect(state.randomCallCountValue() == 0)
        #expect(state.sleepCallCountValue() == 0)
    }

    @Test
    func requestIfNeeded_returns_skipped_by_policy_without_sleep_when_lottery_misses() async {
        let state = InvocationState()
        let policy = MHReviewPolicy(
            lotteryMaxExclusive: 5,
            requestDelay: .seconds(2)
        )

        let outcome = await MHReviewRequester.requestIfNeeded(
            policy: policy,
            randomValueProvider: { range in
                state.recordRandomCall()
                return range.upperBound - 1
            },
            sleep: { _ in
                state.recordSleepCall()
            }
        )

        #expect(outcome == .skippedByPolicy)
        #expect(state.randomCallCountValue() == 1)
        #expect(state.sleepCallCountValue() == 0)
    }

    @Test
    func requestIfNeeded_sleeps_once_before_attempt_when_lottery_hits() async {
        let state = InvocationState()
        let policy = MHReviewPolicy(
            lotteryMaxExclusive: 5,
            requestDelay: .seconds(2)
        )
        let environment = MHReviewRequestEnvironment {
            state.recordEvent("request")
            return .requested
        }

        let outcome = await MHReviewRequester.requestIfNeeded(
            policy: policy,
            randomValueProvider: { _ in
                state.recordRandomCall()
                return 0
            },
            sleep: { _ in
                state.recordSleepCall()
                state.recordEvent("sleep")
            },
            environment: environment
        )

        #expect(outcome == .requested)
        #expect(state.randomCallCountValue() == 1)
        #expect(state.sleepCallCountValue() == 1)
        #expect(state.eventsValue() == ["sleep", "request"])
    }

    #if os(iOS)
    @Test
    @MainActor
    func requestReview_returns_skipped_no_foreground_scene_when_scene_missing() {
        let outcome = MHReviewRequester.requestReview(
            connectedScenes: []
        ) { _ in
            Issue.record("request closure should not be called")
        }

        #expect(outcome == .skippedNoForegroundScene)
    }
    #else
    @Test
    func requestIfNeeded_returns_unsupported_platform_on_non_iOS() async {
        let policy = MHReviewPolicy(
            lotteryMaxExclusive: 5,
            requestDelay: .zero
        )

        let outcome = await MHReviewRequester.requestIfNeeded(policy: policy) { _ in
            0
        }

        #expect(outcome == .unsupportedPlatform)
    }
    #endif
}
