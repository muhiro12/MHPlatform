import Foundation

/// Persisted evidence for one app and storefront, re-evaluated at every check.
public struct MHRemoteUpdateSnapshot: Codable, Equatable, Sendable {
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
    /// The storefront in which publication evidence was obtained.
    public let storefront: String
    /// Optional evidence; its absence never clears a known schedule.
    public let publication: Publication?

    /// Creates a snapshot for the app-owned storage location.
    public init(schedule: MHRemoteUpdateSchedule, storefront: String, publication: Publication?) {
        self.schedule = schedule
        self.storefront = storefront
        self.publication = publication
    }

    /// Expired documents or unconfirmed publication become unavailable, never permission.
    public func evaluate(
        currentVersion: MHAppVersion,
        now: Date,
        maximumValidity: TimeInterval,
        maximumPublicationAge: TimeInterval
    ) -> MHRemoteUpdateDecision {
        guard schedule.isValid(at: now, maximumValidity: maximumValidity) else {
            return .unavailable
        }
        guard let requirement = schedule.requirement,
              currentVersion < requirement.minimumVersion,
              now >= requirement.effectiveAt,
              requirement.endsAt.map({ now <= $0 }) != false else {
            return .notRequired
        }
        guard let publication, publication.isValid(at: now, maximumAge: maximumPublicationAge),
              publication.version >= requirement.minimumVersion else {
            return .unavailable
        }
        return .updateRequired
    }
}
