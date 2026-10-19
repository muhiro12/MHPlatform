import Foundation

/// Persisted evidence for one app and storefront, re-evaluated at every check.
public struct MHRemoteUpdateSnapshot: Codable, Equatable, Sendable {
    /// Time-bounded evidence of an accepted policy fetch.
    public struct Observation: Codable, Equatable, Sendable {
        /// When an accepted policy fetch completed.
        public let fetchedAt: Date
        /// The exclusive expiry of retained policy evidence.
        public let validUntil: Date

        /// Records an observation without choosing a package-default lifetime.
        public init(fetchedAt: Date, validUntil: Date) {
            self.fetchedAt = fetchedAt
            self.validUntil = validUntil
        }

        func isValid(at date: Date, maximumAge: TimeInterval) -> Bool {
            maximumAge.isFinite && maximumAge > 0
                && fetchedAt.timeIntervalSinceReferenceDate.isFinite
                && validUntil.timeIntervalSinceReferenceDate.isFinite
                && date.timeIntervalSinceReferenceDate.isFinite
                && fetchedAt <= date && date < validUntil
                && date.timeIntervalSince(fetchedAt) < maximumAge
        }
    }

    /// Time-bounded publication evidence supplied by the app's identity-validated lookup.
    public struct Publication: Codable, Equatable, Sendable {
        /// The version observed in the selected storefront.
        public let version: MHAppVersion
        /// When the lookup completed.
        public let checkedAt: Date
        /// The exclusive end of the app-selected evidence lifetime.
        public let validUntil: Date

        /// Creates evidence without supplying a package-default lifetime.
        public init(version: MHAppVersion, checkedAt: Date, validUntil: Date) {
            self.version = version
            self.checkedAt = checkedAt
            self.validUntil = validUntil
        }

        func isValid(at date: Date, maximumAge: TimeInterval) -> Bool {
            maximumAge.isFinite && maximumAge > 0
                && checkedAt.timeIntervalSinceReferenceDate.isFinite
                && validUntil.timeIntervalSinceReferenceDate.isFinite
                && checkedAt <= date && date < validUntil
                && date.timeIntervalSince(checkedAt) < maximumAge
        }
    }

    /// The retained remote schedule, including future requirements or cancellation.
    public let schedule: MHRemoteUpdateSchedule
    /// Freshness of the retained policy; local reads never renew it.
    public let observation: Observation
    /// The storefront in which publication evidence was obtained.
    public let storefront: String?
    /// Optional evidence; its absence never clears a known schedule.
    public let publication: Publication?

    /// Creates a snapshot for the app-owned storage location.
    public init(
        schedule: MHRemoteUpdateSchedule,
        storefront: String?,
        observation: Observation,
        publication: Publication?
    ) {
        self.schedule = schedule
        self.storefront = storefront
        self.observation = observation
        self.publication = publication
    }

    /// Expired policy evidence or unconfirmed publication become unavailable, never permission.
    public func evaluate(
        currentVersion: MHAppVersion,
        now: Date,
        maximumPolicyAge: TimeInterval,
        maximumPublicationAge: TimeInterval
    ) -> MHRemoteUpdateDecision {
        guard observation.isValid(at: now, maximumAge: maximumPolicyAge) else {
            return .unavailable
        }
        guard let minimumVersion = schedule.minimumVersion(at: now), currentVersion < minimumVersion else {
            return .notRequired
        }
        guard let publication, publication.isValid(at: now, maximumAge: maximumPublicationAge),
              publication.version >= minimumVersion else {
            return .unavailable
        }
        return .updateRequired
    }
}
