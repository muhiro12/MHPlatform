import Foundation

/// Evaluates app-supplied policy using injectable installed-version, clock, and lookup providers.
public struct MHRemoteUpdateEvaluator: Sendable {
    private let currentVersion: @Sendable () -> String?
    private let now: @Sendable () -> Date
    private let publicVersion: @Sendable () async throws -> MHAppVersion?

    /// Creates a schema-independent evaluator. A missing public version is unavailable
    /// only when the policy requires publication evidence.
    @preconcurrency
    public init(
        currentVersion: @escaping @Sendable () -> String? = {
            Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        },
        now: @escaping @Sendable () -> Date = Date.init,
        publicVersion: @escaping @Sendable () async throws -> MHAppVersion? = {
            nil
        }
    ) {
        self.currentVersion = currentVersion
        self.now = now
        self.publicVersion = publicVersion
    }

    /// Returns unavailable for missing policy or malformed installed versions.
    ///
    /// Fetches only when publication evidence is needed, then samples time again so
    /// a policy expiring during lookup cannot require an update. Errors propagate;
    /// the app owns logging, refresh, and recovery. Cancellation is never a decision.
    public func evaluate(_ policy: MHRemoteUpdatePolicy?) async throws -> MHRemoteUpdateDecision {
        try Task.checkCancellation()
        guard let policy,
              let installedVersion = currentVersion().flatMap(MHAppVersion.init) else {
            return .unavailable
        }
        let evaluationDate = now()
        guard evaluationDate.timeIntervalSinceReferenceDate.isFinite else {
            return .unavailable
        }
        let initialDecision = policy.evaluate(currentVersion: installedVersion, now: evaluationDate)
        guard initialDecision == .unavailable, policy.requiresPublicVersion else {
            return initialDecision
        }
        do {
            let resolvedVersion = try await publicVersion()
            try Task.checkCancellation()
            return policy.evaluate(currentVersion: installedVersion, now: now(), publicVersion: resolvedVersion)
        } catch {
            if error is CancellationError || Task.isCancelled || (error as? URLError)?.code == .cancelled {
                throw CancellationError()
            }
            throw error
        }
    }
}
