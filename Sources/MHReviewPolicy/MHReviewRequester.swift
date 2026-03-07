import Foundation
import MHLogging

#if os(iOS)
import UIKit
#endif

/// High-level requester for in-app review prompts.
public enum MHReviewRequester {
    /// Closure used for generating lottery values.
    public typealias RandomValueProvider = @Sendable (Range<Int>) -> Int

    /// Closure used for sleeping before review requests.
    public typealias Sleep = @Sendable (Duration) async -> Void

    /// Requests an in-app review when the policy allows it.
    @MainActor
    @preconcurrency
    public static func requestIfNeeded(
        policy: MHReviewPolicy,
        randomValueProvider: RandomValueProvider = { range in
            Int.random(in: range)
        },
        sleep: Sleep = { duration in
            try? await Task.sleep(for: duration)
        }
    ) async -> MHReviewRequestOutcome {
        await requestIfNeeded(
            policy: policy,
            randomValueProvider: randomValueProvider,
            sleep: sleep,
            environment: .live
        )
    }

    /// Requests an in-app review when the policy allows it and reports the terminal outcome.
    @MainActor
    @preconcurrency
    public static func requestIfNeeded(
        policy: MHReviewPolicy,
        randomValueProvider: RandomValueProvider = { range in
            Int.random(in: range)
        },
        sleep: Sleep = { duration in
            try? await Task.sleep(for: duration)
        },
        onOutcome: @Sendable (MHReviewRequestOutcome) -> Void
    ) async -> MHReviewRequestOutcome {
        await requestIfNeeded(
            policy: policy,
            randomValueProvider: randomValueProvider,
            sleep: sleep,
            environment: .live,
            onOutcome: onOutcome
        )
    }

    /// Requests an in-app review when the policy allows it and logs terminal outcomes.
    @MainActor
    @preconcurrency
    public static func requestIfNeeded(
        policy: MHReviewPolicy,
        logger: MHLogger,
        randomValueProvider: RandomValueProvider = { range in
            Int.random(in: range)
        },
        sleep: Sleep = { duration in
            try? await Task.sleep(for: duration)
        }
    ) async -> MHReviewRequestOutcome {
        await requestIfNeeded(
            policy: policy,
            randomValueProvider: randomValueProvider,
            sleep: sleep,
            environment: .live,
            logger: logger
        )
    }

    @MainActor
    static func requestIfNeeded(
        policy: MHReviewPolicy,
        randomValueProvider: RandomValueProvider,
        sleep: Sleep,
        environment: MHReviewRequestEnvironment,
        onOutcome: @Sendable (MHReviewRequestOutcome) -> Void = { _ in
            // no-op
        }
    ) async -> MHReviewRequestOutcome {
        guard policy.lotteryMaxExclusive > 0 else {
            return finish(
                .skippedInvalidLotteryRange,
                onOutcome: onOutcome
            )
        }

        let randomValue = randomValueProvider(0..<policy.lotteryMaxExclusive)
        guard policy.shouldRequestReview(randomValue: randomValue) else {
            return finish(
                .skippedByPolicy,
                onOutcome: onOutcome
            )
        }

        if policy.requestDelay != .zero {
            await sleep(policy.requestDelay)
        }

        return finish(
            environment.requestReview(),
            onOutcome: onOutcome
        )
    }

    @MainActor
    static func requestIfNeeded(
        policy: MHReviewPolicy,
        randomValueProvider: RandomValueProvider,
        sleep: Sleep,
        environment: MHReviewRequestEnvironment,
        logger: MHLogger
    ) async -> MHReviewRequestOutcome {
        let outcome = await requestIfNeeded(
            policy: policy,
            randomValueProvider: randomValueProvider,
            sleep: sleep,
            environment: environment
        )
        await logOutcome(
            outcome,
            logger: logger
        )
        return outcome
    }
}

extension MHReviewRequester {
    static func logOutcome(
        _ outcome: MHReviewRequestOutcome,
        logger: MHLogger
    ) async {
        switch outcome {
        case .requested:
            await logger.logImmediately(
                .notice,
                "review request invoked"
            )
        case .skippedInvalidLotteryRange:
            await logger.logImmediately(
                .warning,
                "review request skipped because the lottery range was invalid"
            )
        case .skippedNoForegroundScene:
            await logger.logImmediately(
                .info,
                "review request skipped because no foreground scene was available"
            )
        case .unsupportedPlatform:
            await logger.logImmediately(
                .info,
                "review request skipped because the platform is unsupported"
            )
        case .skippedByPolicy:
            break
        }
    }
}

private extension MHReviewRequester {
    static func finish(
        _ outcome: MHReviewRequestOutcome,
        onOutcome: @Sendable (MHReviewRequestOutcome) -> Void
    ) -> MHReviewRequestOutcome {
        onOutcome(outcome)
        return outcome
    }
}

#if os(iOS)
@MainActor
extension MHReviewRequester {
    static func requestReview(
        connectedScenes: Set<UIScene>,
        request: @MainActor (UIWindowScene) -> Void
    ) -> MHReviewRequestOutcome {
        guard let windowScene = connectedScenes
                .compactMap({ scene in
                    scene as? UIWindowScene
                })
                .first(where: { windowScene in
                    windowScene.activationState == .foregroundActive
                }) else {
            return .skippedNoForegroundScene
        }

        request(windowScene)
        return .requested
    }
}
#endif
