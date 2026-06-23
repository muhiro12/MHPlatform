import Foundation
import MHReviewPolicy

#if os(iOS)
import UIKit
#endif

/// High-level requester for in-app review prompts.
public enum MHReviewRequester {
    /// Closure used for generating lottery values.
    public typealias RandomValueProvider = @Sendable (Range<Int>) -> Int

    /// Closure used for sleeping before review requests.
    public typealias Sleep = @Sendable (Duration) async -> Void

    package struct RequestContext: Sendable {
        let policy: MHReviewPolicy
        let randomValueProvider: RandomValueProvider
        let sleep: Sleep
        let environment: MHReviewRequestEnvironment
        let onOutcome: @Sendable (MHReviewRequestOutcome) -> Void

        package init(
            policy: MHReviewPolicy,
            randomValueProvider: @escaping RandomValueProvider,
            sleep: @escaping Sleep,
            environment: MHReviewRequestEnvironment,
            onOutcome: @escaping @Sendable (MHReviewRequestOutcome) -> Void
        ) {
            self.policy = policy
            self.randomValueProvider = randomValueProvider
            self.sleep = sleep
            self.environment = environment
            self.onOutcome = onOutcome
        }
    }

    /// Requests an in-app review when the policy allows it.
    ///
    /// Prefer `MHReviewFlow` when review triggering should be wired into
    /// runtime tasks or mutation steps. Use this low-level requester only for
    /// direct one-off calls.
    @MainActor
    @preconcurrency
    public static func requestIfNeeded(
        policy: MHReviewPolicy,
        randomValueProvider: @escaping RandomValueProvider = { range in
            Int.random(in: range)
        },
        sleep: @escaping Sleep = { duration in
            try? await Task.sleep(for: duration)
        }
    ) async -> MHReviewRequestOutcome {
        let ignoreOutcome: @Sendable (MHReviewRequestOutcome) -> Void = { _ in
            // no-op
        }

        return await requestIfNeeded(
            .init(
                policy: policy,
                randomValueProvider: randomValueProvider,
                sleep: sleep,
                environment: .live,
                onOutcome: ignoreOutcome
            )
        )
    }

    /// Requests an in-app review when the policy allows it and reports the terminal outcome.
    ///
    /// Prefer `MHReviewFlow` when the caller also needs package-owned trigger
    /// metadata, logging, or workflow integration.
    @MainActor
    @preconcurrency
    public static func requestIfNeeded(
        policy: MHReviewPolicy,
        randomValueProvider: @escaping RandomValueProvider = { range in
            Int.random(in: range)
        },
        sleep: @escaping Sleep = { duration in
            try? await Task.sleep(for: duration)
        },
        onOutcome: @escaping @Sendable (MHReviewRequestOutcome) -> Void
    ) async -> MHReviewRequestOutcome {
        await requestIfNeeded(
            .init(
                policy: policy,
                randomValueProvider: randomValueProvider,
                sleep: sleep,
                environment: .live,
                onOutcome: onOutcome
            )
        )
    }

    @MainActor
    package static func requestIfNeeded(
        _ context: RequestContext
    ) async -> MHReviewRequestOutcome {
        guard context.policy.lotteryMaxExclusive > 0 else {
            return finish(
                .skippedInvalidLotteryRange,
                onOutcome: context.onOutcome
            )
        }

        let randomValue = context.randomValueProvider(0..<context.policy.lotteryMaxExclusive)
        guard context.policy.shouldRequestReview(randomValue: randomValue) else {
            return finish(
                .skippedByPolicy,
                onOutcome: context.onOutcome
            )
        }

        if context.policy.requestDelay != .zero {
            await context.sleep(context.policy.requestDelay)
        }

        return finish(
            context.environment.requestReview(),
            onOutcome: context.onOutcome
        )
    }
}

private extension MHReviewRequester {
    @MainActor
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
