import Foundation

/// A read-only explanation of one evaluation instant, never durable operation permission.
public struct MHRemoteUpdateEvaluation: Sendable {
    /// The condition that determines the decision; retrieval errors are reported separately.
    public enum Reason: String, Sendable {
        /// Invalid installed version takes precedence over missing or unusable policy evidence.
        case installedVersionInvalid, policyMissing, policyExpired, policyInvalid
        /// Valid policy permits the installed version without requiring publication evidence.
        case noActiveRequirement, installedVersionAccepted
        /// An active minimum needs publication evidence that is absent, unusable, or too low.
        case publicationMissing, publicationExpired, publicationInvalid, publicationInsufficient
        /// The installed version is below an active, confirmed published minimum.
        case updateRequired

        var decision: MHRemoteUpdateDecision {
            switch self {
            case .noActiveRequirement, .installedVersionAccepted:
                return .notRequired
            case .updateRequired:
                return .updateRequired
            default:
                return .unavailable
            }
        }
    }

    /// Freshness under the controller's current maximum age and the retained expiry.
    public enum Freshness: String, Sendable {
        case missing, fresh, expired, invalid

        static func evaluate(observedAt: Date, validUntil: Date, now: Date, maximumAge: TimeInterval) -> Self {
            guard maximumAge.isFinite, maximumAge > 0,
                  observedAt.timeIntervalSinceReferenceDate.isFinite,
                  validUntil.timeIntervalSinceReferenceDate.isFinite,
                  now.timeIntervalSinceReferenceDate.isFinite,
                  validUntil > observedAt, observedAt <= now else {
                return .invalid
            }
            return now < validUntil && now.timeIntervalSince(observedAt) < maximumAge ? .fresh : .expired
        }
    }

    /// A stable diagnostic category; user-facing wording remains app-owned.
    public let reason: Reason
    /// The single clock observation used for minimum selection and both freshness checks.
    public let evaluatedAt: Date
    /// Nil when the installed version is missing or invalid.
    public let installedVersion: MHAppVersion?
    /// The accepted revision, even when its retained evidence has expired.
    public let revision: Int?
    /// The strictest active baseline or plan; nil when none applies or no policy is known.
    public let minimumVersion: MHAppVersion?
    /// Original policy timestamps; reading this value never renews them.
    public let observation: MHRemoteUpdateSnapshot.Observation?
    /// Original publication version and timestamps, if any.
    public let publication: MHRemoteUpdateSnapshot.Publication?
    /// Freshness of the accepted policy under the current local maximum age.
    public let policyFreshness: Freshness
    /// Freshness of publication evidence, even when the installed version needs no update.
    public let publicationFreshness: Freshness
    /// Failure of the most recent restoration attempt; cleared by successful restoration.
    public let restorationError: (any Error)?
    /// Failure of the most recent non-cancelled refresh; cleared by successful refresh.
    public let refreshError: (any Error)?

    /// The ordinary decision produced by this exact evaluation.
    public var decision: MHRemoteUpdateDecision { reason.decision }

    init(
        snapshot: MHRemoteUpdateSnapshot?,
        installedVersion: MHAppVersion?,
        now: Date,
        maximumPolicyAge: TimeInterval,
        maximumPublicationAge: TimeInterval,
        restorationError: (any Error)?,
        refreshError: (any Error)?
    ) {
        evaluatedAt = now
        self.installedVersion = installedVersion
        revision = snapshot?.schedule.revision
        minimumVersion = now.timeIntervalSinceReferenceDate.isFinite ? snapshot?.schedule.minimumVersion(at: now) : nil
        observation = snapshot?.observation
        publication = snapshot?.publication
        policyFreshness = snapshot?.observation.freshness(at: now, maximumAge: maximumPolicyAge) ?? .missing
        publicationFreshness = snapshot?.publication?.freshness(at: now, maximumAge: maximumPublicationAge) ?? .missing
        self.restorationError = restorationError
        self.refreshError = refreshError
        reason = Self.reason(
            installedVersion: installedVersion,
            minimumVersion: minimumVersion,
            policy: policyFreshness,
            publication: publicationFreshness,
            publishedVersion: publication?.version
        )
    }

    private static func reason(
        installedVersion: MHAppVersion?,
        minimumVersion: MHAppVersion?,
        policy: Freshness,
        publication: Freshness,
        publishedVersion: MHAppVersion?
    ) -> Reason {
        guard let installedVersion else {
            return .installedVersionInvalid
        }
        switch policy {
        case .missing:
            return .policyMissing
        case .expired:
            return .policyExpired
        case .invalid:
            return .policyInvalid
        case .fresh:
            break
        }
        guard let minimumVersion else {
            return .noActiveRequirement
        }
        guard installedVersion < minimumVersion else {
            return .installedVersionAccepted
        }
        return publicationReason(publication, version: publishedVersion, minimum: minimumVersion)
    }

    private static func publicationReason(
        _ publication: Freshness, version: MHAppVersion?, minimum: MHAppVersion
    ) -> Reason {
        switch publication {
        case .missing:
            return .publicationMissing
        case .expired:
            return .publicationExpired
        case .invalid:
            return .publicationInvalid
        case .fresh:
            break
        }
        return version.map { $0 >= minimum } == true ? .updateRequired : .publicationInsufficient
    }
}
