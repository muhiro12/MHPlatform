import MHAppRuntime
import MHLogging
import MHMutationFlow

/// Package-owned shell for review-request orchestration and lifecycle wiring.
public struct MHReviewFlow: Sendable {
    /// Closure used for observing terminal outcomes.
    public typealias OutcomeSink = @Sendable (MHReviewRequestOutcome) -> Void

    /// Review request policy applied by this flow.
    public let policy: MHReviewPolicy

    private let logger: MHLogger?
    private let onOutcome: OutcomeSink
    private let randomValueProvider: MHReviewRequester.RandomValueProvider
    private let sleep: MHReviewRequester.Sleep
    private let environment: MHReviewRequestEnvironment

    /// Creates a review flow with optional logging and deterministic test hooks.
    @preconcurrency
    public init(
        policy: MHReviewPolicy,
        logger: MHLogger? = nil,
        onOutcome: @escaping OutcomeSink = { _ in
            // Intentionally empty.
        },
        randomValueProvider: @escaping MHReviewRequester.RandomValueProvider = { range in
            Int.random(in: range)
        },
        sleep: @escaping MHReviewRequester.Sleep = { duration in
            try? await Task.sleep(for: duration)
        }
    ) {
        self.init(
            policy: policy,
            logger: logger,
            onOutcome: onOutcome,
            randomValueProvider: randomValueProvider,
            sleep: sleep,
            environment: .live
        )
    }

    init(
        policy: MHReviewPolicy,
        logger: MHLogger?,
        onOutcome: @escaping OutcomeSink,
        randomValueProvider: @escaping MHReviewRequester.RandomValueProvider,
        sleep: @escaping MHReviewRequester.Sleep,
        environment: MHReviewRequestEnvironment
    ) {
        self.policy = policy
        self.logger = logger
        self.onOutcome = onOutcome
        self.randomValueProvider = randomValueProvider
        self.sleep = sleep
        self.environment = environment
    }

    /// Runs the review-request flow immediately.
    @preconcurrency
    @MainActor
    public func requestIfNeeded() async -> MHReviewRequestOutcome {
        await requestIfNeeded(logMetadata: [:])
    }

    /// Builds a runtime task that requests review exactly once per task run.
    public func task(
        name: String
    ) -> MHAppRuntimeTask {
        .init(name: name) {
            _ = await requestIfNeeded(
                logMetadata: [
                    "reviewTrigger": "runtimeTask",
                    "reviewTriggerName": name
                ]
            )
        }
    }

    /// Builds a mutation step that requests review exactly once per step run.
    public func step(
        name: String
    ) -> MHMutationStep {
        .mainActor(name: name) {
            _ = await requestIfNeeded(
                logMetadata: [
                    "reviewTrigger": "mutationStep",
                    "reviewTriggerName": name
                ]
            )
        }
    }
}

private extension MHReviewFlow {
    @MainActor
    func requestIfNeeded(
        logMetadata: [String: String]
    ) async -> MHReviewRequestOutcome {
        await MHReviewRequester.requestIfNeeded(
            policy: policy,
            randomValueProvider: randomValueProvider,
            sleep: sleep,
            environment: environment,
            logger: logger,
            onOutcome: onOutcome,
            logMetadata: logMetadata
        )
    }
}
