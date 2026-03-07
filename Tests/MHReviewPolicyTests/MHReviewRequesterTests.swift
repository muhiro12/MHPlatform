@testable import MHLogging
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
    func requestIfNeeded_reports_skipped_invalid_range_once() async {
        let state = InvocationState()
        let policy = MHReviewPolicy(
            lotteryMaxExclusive: 0,
            requestDelay: .seconds(2)
        )

        let outcome = await MHReviewRequester.requestIfNeeded(policy: policy) { reportedOutcome in
            state.recordEvent(String(describing: reportedOutcome))
        }

        #expect(outcome == .skippedInvalidLotteryRange)
        #expect(state.eventsValue() == ["skippedInvalidLotteryRange"])
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
    func requestIfNeeded_reports_skipped_by_policy_once() async {
        let state = InvocationState()
        let policy = MHReviewPolicy(
            lotteryMaxExclusive: 5,
            requestDelay: .seconds(2)
        )

        let outcome = await MHReviewRequester.requestIfNeeded(
            policy: policy,
            randomValueProvider: { range in
                range.upperBound - 1
            },
            onOutcome: { reportedOutcome in
                state.recordEvent(String(describing: reportedOutcome))
            }
        )

        #expect(outcome == .skippedByPolicy)
        #expect(state.eventsValue() == ["skippedByPolicy"])
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

    @Test
    func requestIfNeeded_reports_requested_once() async {
        let state = InvocationState()
        let policy = MHReviewPolicy(
            lotteryMaxExclusive: 5,
            requestDelay: .zero
        )
        let randomValueProvider: @Sendable (Range<Int>) -> Int = { _ in
            0
        }
        let sleep: @Sendable (Duration) async -> Void = { _ in
            Issue.record("sleep should not be called")
        }
        let environment = MHReviewRequestEnvironment {
            .requested
        }

        let outcome = await MHReviewRequester.requestIfNeeded(
            policy: policy,
            randomValueProvider: randomValueProvider,
            sleep: sleep,
            environment: environment
        ) { reportedOutcome in
            state.recordEvent(String(describing: reportedOutcome))
        }

        #expect(outcome == .requested)
        #expect(state.eventsValue() == ["requested"])
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

    @Test
    func logOutcome_logs_expected_messages_for_terminal_outcomes() async {
        let store = MHLogStore(
            policy: .init(
                minimumLevel: .debug,
                persistsToDisk: false,
                maximumInMemoryEvents: 20,
                maximumDiskBytes: 1_000
            )
        )
        let logger = MHLogger(
            "Tests/MHReviewRequesterTests.swift",
            store: store,
            subsystem: "tests.review"
        )

        MHReviewRequester.logOutcome(
            .requested,
            logger: logger
        )
        MHReviewRequester.logOutcome(
            .skippedInvalidLotteryRange,
            logger: logger
        )
        MHReviewRequester.logOutcome(
            .skippedNoForegroundScene,
            logger: logger
        )
        MHReviewRequester.logOutcome(
            .unsupportedPlatform,
            logger: logger
        )
        MHReviewRequester.logOutcome(
            .skippedByPolicy,
            logger: logger
        )

        try? await Task.sleep(for: .milliseconds(50))
        let events = await store.events()
        #expect(events.map(\.level) == [
            .notice,
            .warning,
            .info,
            .info
        ])
        #expect(events.map(\.message) == [
            "review request invoked",
            "review request skipped because the lottery range was invalid",
            "review request skipped because no foreground scene was available",
            "review request skipped because the platform is unsupported"
        ])
    }
}
