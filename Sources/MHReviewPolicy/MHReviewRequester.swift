import Foundation

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

    @MainActor
    static func requestIfNeeded(
        policy: MHReviewPolicy,
        randomValueProvider: RandomValueProvider,
        sleep: Sleep,
        environment: MHReviewRequestEnvironment
    ) async -> MHReviewRequestOutcome {
        guard policy.lotteryMaxExclusive > 0 else {
            return .skippedInvalidLotteryRange
        }

        let randomValue = randomValueProvider(0..<policy.lotteryMaxExclusive)
        guard policy.shouldRequestReview(randomValue: randomValue) else {
            return .skippedByPolicy
        }

        if policy.requestDelay != .zero {
            await sleep(policy.requestDelay)
        }

        return environment.requestReview()
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
