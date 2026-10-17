import Foundation
import MHRemoteUpdate

extension SurfaceAdapterConsumer {
    private enum UpdateConstants {
        static let maximumHours = 72
        static let minutesPerHour = 60
        static let secondsPerMinute = 60
        static let maximumActivationDuration = TimeInterval(maximumHours * minutesPerHour * secondsPerMinute)
    }

    private struct UpdateDocument: Decodable {
        let minimumVersion: String
        let activatedAt: Date
        let expiresAt: Date
    }

    enum UpdateFailure: Error {
        case invalidPolicy
    }

    /// The adapter owns its JSON schema, activation limit, and public-version provider.
    static func updateDecision(
        document: Data,
        currentVersion: String,
        now: Date,
        publicVersion: @escaping @Sendable () async throws -> MHAppVersion?
    ) async throws -> MHRemoteUpdateDecision {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let configuration = try decoder.decode(UpdateDocument.self, from: document)
        guard let minimum = MHAppVersion(configuration.minimumVersion),
              let window = MHUpdateActivationWindow(
                activatedAt: configuration.activatedAt,
                expiresAt: configuration.expiresAt,
                maximumDuration: UpdateConstants.maximumActivationDuration
              ) else {
            throw UpdateFailure.invalidPolicy
        }
        let policy = MHRemoteUpdatePolicy(
            minimumVersion: minimum,
            activationWindow: window,
            requiresPublicVersion: true
        )
        let evaluator = MHRemoteUpdateEvaluator(currentVersion: {
            currentVersion
        }, now: {
            now
        }, publicVersion: publicVersion)
        return try await evaluator.evaluate(policy)
    }

    /// Both UI and App Intent-style callers enter this same app-owned operation.
    static func performProtectedOperation(
        decision: MHRemoteUpdateDecision,
        whenUnavailable behavior: MHRemoteUpdateUnavailableBehavior,
        mutation: @Sendable () async throws -> Void,
        afterSuccess: @Sendable () async throws -> Void
    ) async throws {
        try Task.checkCancellation()
        try decision.checkOperationAllowed(whenUnavailable: behavior)
        try await mutation()
        try await afterSuccess()
    }
}
