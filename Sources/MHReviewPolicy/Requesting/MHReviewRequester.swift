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

    struct RequestContext: Sendable {
        let policy: MHReviewPolicy
        let randomValueProvider: RandomValueProvider
        let sleep: Sleep
        let environment: MHReviewRequestEnvironment
        let logger: MHLogger?
        let onOutcome: @Sendable (MHReviewRequestOutcome) -> Void
        let logMetadata: [String: String]
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
        await requestIfNeeded(
            .init(
                policy: policy,
                randomValueProvider: randomValueProvider,
                sleep: sleep,
                environment: .live,
                logger: nil,
                onOutcome: { _ in
                    // no-op
                },
                logMetadata: [:]
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
                logger: nil,
                onOutcome: onOutcome,
                logMetadata: [:]
            )
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
        randomValueProvider: @escaping RandomValueProvider = { range in
            Int.random(in: range)
        },
        sleep: @escaping Sleep = { duration in
            try? await Task.sleep(for: duration)
        }
    ) async -> MHReviewRequestOutcome {
        await requestIfNeeded(
            .init(
                policy: policy,
                randomValueProvider: randomValueProvider,
                sleep: sleep,
                environment: .live,
                logger: logger,
                onOutcome: { _ in
                    // no-op
                },
                logMetadata: [:]
            )
        )
    }

    @MainActor
    static func requestIfNeeded(
        _ context: RequestContext
    ) async -> MHReviewRequestOutcome {
        guard context.policy.lotteryMaxExclusive > 0 else {
            return await finish(
                .skippedInvalidLotteryRange,
                logger: context.logger,
                onOutcome: context.onOutcome,
                logMetadata: context.logMetadata
            )
        }

        let randomValue = context.randomValueProvider(0..<context.policy.lotteryMaxExclusive)
        guard context.policy.shouldRequestReview(randomValue: randomValue) else {
            return await finish(
                .skippedByPolicy,
                logger: context.logger,
                onOutcome: context.onOutcome,
                logMetadata: context.logMetadata
            )
        }

        if context.policy.requestDelay != .zero {
            await context.sleep(context.policy.requestDelay)
        }

        return await finish(
            context.environment.requestReview(),
            logger: context.logger,
            onOutcome: context.onOutcome,
            logMetadata: context.logMetadata
        )
    }
}

extension MHReviewRequester {
    static func logOutcome(
        _ outcome: MHReviewRequestOutcome,
        logger: MHLogger,
        metadata: [String: String]
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
