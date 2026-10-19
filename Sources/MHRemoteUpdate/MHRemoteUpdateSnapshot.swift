import Foundation

/// Persisted evidence for one app and storefront, re-evaluated at every check.
public struct MHRemoteUpdateSnapshot: Codable, Equatable, Sendable {
    private enum CodingKeys: String, CodingKey {
        case schedule, observation, storefront, publication, publicationCheckedAt
    }
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

        func freshness(at date: Date, maximumAge: TimeInterval) -> MHRemoteUpdateEvaluation.Freshness {
            .evaluate(observedAt: fetchedAt, validUntil: validUntil, now: date, maximumAge: maximumAge)
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

        func freshness(at date: Date, maximumAge: TimeInterval) -> MHRemoteUpdateEvaluation.Freshness {
            .evaluate(observedAt: checkedAt, validUntil: validUntil, now: date, maximumAge: maximumAge)
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

    // A successful empty lookup must supersede older positive publication evidence.
    var publicationCheckedAt: Date?

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
        publicationCheckedAt = publication?.checkedAt
    }

    /// Restores private cache data without interpreting a disk read as a network observation.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            schedule: try container.decode(RemoteUpdateCachedSchedule.self, forKey: .schedule).schedule(),
            storefront: try container.decodeIfPresent(String.self, forKey: .storefront),
            observation: try container.decode(Observation.self, forKey: .observation),
            publication: try container.decodeIfPresent(Publication.self, forKey: .publication)
        )
        publicationCheckedAt = try container.decodeIfPresent(Date.self, forKey: .publicationCheckedAt)
            ?? publication?.checkedAt
    }

    /// Keeps cache representation separate from the public schedule's shared Config envelope.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(RemoteUpdateCachedSchedule(schedule), forKey: .schedule)
        try container.encode(observation, forKey: .observation)
        try container.encodeIfPresent(storefront, forKey: .storefront)
        try container.encodeIfPresent(publication, forKey: .publication)
        try container.encodeIfPresent(publicationCheckedAt, forKey: .publicationCheckedAt)
    }

    func merging(_ incoming: Self) throws -> Self {
        guard schedule.bundleIdentifier == incoming.schedule.bundleIdentifier, storefront == incoming.storefront else {
            throw MHRemoteUpdateController.Failure.identityMismatch
        }
        guard incoming.schedule.revision >= schedule.revision,
              incoming.schedule.revision != schedule.revision || incoming.schedule == schedule else {
            throw MHRemoteUpdateController.Failure.revisionConflict
        }
        let latestObservation = incoming.schedule.revision > schedule.revision
            || incoming.observation.fetchedAt > self.observation.fetchedAt ? incoming.observation : self.observation
        let publicationSource = (incoming.publicationCheckedAt ?? .distantPast)
            >= (publicationCheckedAt ?? .distantPast) ? incoming : self
        var merged = Self(
            schedule: incoming.schedule,
            storefront: storefront,
            observation: latestObservation,
            publication: publicationSource.publication
        )
        merged.publicationCheckedAt = publicationSource.publicationCheckedAt
        return merged
    }

    /// Expired policy evidence or unconfirmed publication become unavailable, never permission.
    public func evaluate(
        currentVersion: MHAppVersion,
        now: Date,
        maximumPolicyAge: TimeInterval,
        maximumPublicationAge: TimeInterval
    ) -> MHRemoteUpdateDecision {
        evaluation(
            currentVersion: currentVersion,
            now: now,
            maximumPolicyAge: maximumPolicyAge,
            maximumPublicationAge: maximumPublicationAge
        ).decision
    }

    /// Explains the same evaluation without fetching, restoring, saving, or renewing evidence.
    public func evaluation(
        currentVersion: MHAppVersion,
        now: Date,
        maximumPolicyAge: TimeInterval,
        maximumPublicationAge: TimeInterval
    ) -> MHRemoteUpdateEvaluation {
        .init(
            snapshot: self,
            installedVersion: currentVersion,
            now: now,
            maximumPolicyAge: maximumPolicyAge,
            maximumPublicationAge: maximumPublicationAge,
            restorationError: nil,
            refreshError: nil
        )
    }
}
