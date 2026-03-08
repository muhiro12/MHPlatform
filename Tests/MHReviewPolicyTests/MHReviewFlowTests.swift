import MHAppRuntime
@testable import MHLogging
@testable import MHReviewPolicy
import Testing

@MainActor
struct MHReviewFlowTests {
    @Test
    func requestIfNeeded_returns_skipped_invalid_range_without_random_or_sleep() async {
        let state = InvocationState()
        let flow = MHReviewFlow(
            policy: .init(
                lotteryMaxExclusive: 0,
                requestDelay: .seconds(2)
            ),
            logger: nil,
            onOutcome: { outcome in
                state.recordEvent(String(describing: outcome))
            },
            randomValueProvider: { _ in
                state.recordRandomCall()
                return 0
            },
            sleep: { _ in
                state.recordSleepCall()
            },
            environment: .init {
                .requested
            }
        )

        let outcome = await flow.requestIfNeeded()

        #expect(outcome == .skippedInvalidLotteryRange)
        #expect(state.randomCallCountValue() == 0)
        #expect(state.sleepCallCountValue() == 0)
        #expect(state.eventsValue() == ["skippedInvalidLotteryRange"])
    }

    @Test
    func requestIfNeeded_returns_skipped_by_policy_without_logging() async {
        let state = InvocationState()
        let store = Self.makeStore()
        let logger = Self.makeLogger(store: store)
        let flow = MHReviewFlow(
            policy: .init(
                lotteryMaxExclusive: 5,
                requestDelay: .seconds(2)
            ),
            logger: logger,
            onOutcome: { outcome in
                state.recordEvent(String(describing: outcome))
            },
            randomValueProvider: { range in
                state.recordRandomCall()
                return range.upperBound - 1
            },
            sleep: { _ in
                state.recordSleepCall()
            },
            environment: .init {
                state.recordEvent("request")
                return .requested
            }
        )

        let outcome = await flow.requestIfNeeded()
        let events = await store.events()

        #expect(outcome == .skippedByPolicy)
        #expect(state.randomCallCountValue() == 1)
        #expect(state.sleepCallCountValue() == 0)
        #expect(state.eventsValue() == ["skippedByPolicy"])
        #expect(events.isEmpty)
    }

    @Test
    func requestIfNeeded_logs_skipped_no_foreground_scene_and_reports_once() async {
        let state = InvocationState()
        let store = Self.makeStore()
        let logger = Self.makeLogger(store: store)
        let flow = MHReviewFlow(
            policy: .init(
                lotteryMaxExclusive: 5,
                requestDelay: .zero
            ),
            logger: logger,
            onOutcome: { outcome in
                state.recordEvent(String(describing: outcome))
            },
            randomValueProvider: { _ in
                0
            },
            sleep: { _ in
                state.recordSleepCall()
            },
            environment: .init {
                .skippedNoForegroundScene
            }
        )

        let outcome = await flow.requestIfNeeded()
        let events = await store.events()

        #expect(outcome == .skippedNoForegroundScene)
        #expect(state.sleepCallCountValue() == 0)
        #expect(state.eventsValue() == ["skippedNoForegroundScene"])
        #expect(events.map(\.level) == [.info])
        #expect(events.map(\.message) == [
            "review request skipped because no foreground scene was available"
        ])
    }

    @Test
    func task_requests_review_once_per_lifecycle_run() async {
        let state = InvocationState()
        let flow = MHReviewFlow(
            policy: .init(
                lotteryMaxExclusive: 5,
                requestDelay: .zero
            ),
            logger: nil,
            onOutcome: { outcome in
                state.recordEvent(String(describing: outcome))
            },
            randomValueProvider: { _ in
                0
            },
            sleep: { _ in
                state.recordSleepCall()
            },
            environment: .init {
                state.recordEvent("request")
                return .requested
            }
        )
        let runtime = MHAppRuntime(
            configuration: .init(
                showsLicenses: false
            )
        )
        let lifecycle = MHAppRuntimeLifecycle(
            runtime: runtime,
            plan: .init(
                startupTasks: [flow.task(name: "requestReview")],
                skipFirstActivePhase: true
            )
        )

        await lifecycle.handleInitialAppearance()
        await lifecycle.handleInitialAppearance()

        #expect(state.eventsValue() == ["request", "requested"])
        #expect(state.sleepCallCountValue() == 0)
    }

    @Test
    func step_requests_review_once_and_logs_trigger_metadata() async throws {
        let state = InvocationState()
        let store = Self.makeStore()
        let logger = Self.makeLogger(store: store)
        let flow = MHReviewFlow(
            policy: .init(
                lotteryMaxExclusive: 5,
                requestDelay: .zero
            ),
            logger: logger,
            onOutcome: { outcome in
                state.recordEvent(String(describing: outcome))
            },
            randomValueProvider: { _ in
                0
            },
            sleep: { _ in
                state.recordSleepCall()
            },
            environment: .init {
                state.recordEvent("request")
                return .requested
            }
        )

        let step = flow.step(name: "requestReview")
        try await step.action()
        let events = await store.events()

        #expect(state.eventsValue() == ["request", "requested"])
        #expect(events.map(\.message) == ["review request invoked"])
        #expect(events.first?.metadata["reviewTrigger"] == "mutationStep")
        #expect(events.first?.metadata["reviewTriggerName"] == "requestReview")
    }
}

private extension MHReviewFlowTests {
    private enum Constants {
        static let maximumInMemoryEvents = 20
        static let maximumDiskBytes = 1_000
    }

    static func makeStore() -> MHLogStore {
        .init(
            policy: .init(
                minimumLevel: .debug,
                persistsToDisk: false,
                maximumInMemoryEvents: Constants.maximumInMemoryEvents,
                maximumDiskBytes: Constants.maximumDiskBytes
            )
        )
    }

    static func makeLogger(
        store: MHLogStore
    ) -> MHLogger {
        .init(
            "Tests/MHReviewPolicyTests/MHReviewFlowTests.swift",
            store: store,
            subsystem: "tests.review"
        )
    }
}
