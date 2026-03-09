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
    ///
    /// Prefer `MHReviewFlow` when review triggering should be wired into
    /// runtime tasks or mutation steps. Use this low-level requester only for
    /// direct one-off calls.
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
            environment: .live,
            logger: nil
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
            logger: nil,
            onOutcome: onOutcome
        )
    }

    /// Requests an in-app review when the policy allows it and logs terminal outcomes.
    ///
    /// Prefer `MHReviewFlow` when the caller wants package-owned runtime or
    /// mutation wiring in addition to logging.
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
        logger: MHLogger? = nil,
        onOutcome: @Sendable (MHReviewRequestOutcome) -> Void = { _ in
            // no-op
        },
        logMetadata: [String: String] = [:]
    ) async -> MHReviewRequestOutcome {
        guard policy.lotteryMaxExclusive > 0 else {
            return await finish(
                .skippedInvalidLotteryRange,
                logger: logger,
                onOutcome: onOutcome,
                logMetadata: logMetadata
            )
        }

        let randomValue = randomValueProvider(0..<policy.lotteryMaxExclusive)
        guard policy.shouldRequestReview(randomValue: randomValue) else {
            return await finish(
                .skippedByPolicy,
                logger: logger,
                onOutcome: onOutcome,
                logMetadata: logMetadata
            )
        }

        if policy.requestDelay != .zero {
            await sleep(policy.requestDelay)
        }

        return await finish(
            environment.requestReview(),
            logger: logger,
            onOutcome: onOutcome,
            logMetadata: logMetadata
        )
    }
}

extension MHReviewRequester {
    static func logOutcome(
        _ outcome: MHReviewRequestOutcome,
        logger: MHLogger,
        metadata: [String: String] = [:]
    ) async {
        switch outcome {
        case .requested:
            await logger.logImmediately(
                .notice,
                "review request invoked",
                metadata: metadata
            )
        case .skippedInvalidLotteryRange:
            await logger.logImmediately(
                .warning,
                "review request skipped because the lottery range was invalid",
                metadata: metadata
            )
        case .skippedNoForegroundScene:
            await logger.logImmediately(
                .info,
                "review request skipped because no foreground scene was available",
                metadata: metadata
            )
        case .unsupportedPlatform:
            await logger.logImmediately(
                .info,
                "review request skipped because the platform is unsupported",
                metadata: metadata
            )
        case .skippedByPolicy:
            break
        }
    }
}

private extension MHReviewRequester {
    @MainActor
    static func finish(
        _ outcome: MHReviewRequestOutcome,
        logger: MHLogger?,
        onOutcome: @Sendable (MHReviewRequestOutcome) -> Void,
        logMetadata: [String: String]
    ) async -> MHReviewRequestOutcome {
        onOutcome(outcome)

        if let logger {
            await logOutcome(
                outcome,
                logger: logger,
                metadata: logMetadata
            )
        }

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
