import Foundation

/// Private retained-cache v2; legacy bounded snapshots retain their original representation.
struct MHRemoteUpdateEvidence: Codable, Sendable {
    struct Observation: Codable, Sendable {
        let fetchedAt: Date
        let validUntil: Date

        func isValid(at date: Date, maximumAge: TimeInterval) -> Bool {
            maximumAge.isFinite && maximumAge > 0
                && fetchedAt.timeIntervalSinceReferenceDate.isFinite
                && validUntil.timeIntervalSinceReferenceDate.isFinite
                && date.timeIntervalSinceReferenceDate.isFinite
                && fetchedAt <= date && date < validUntil
                && date.timeIntervalSince(fetchedAt) < maximumAge
        }
    }

    let document: MHRemoteUpdateDocument
    let storefront: String
    let observation: Observation?
    var publication: MHRemoteUpdateSnapshot.Publication?

    func evaluate(
        currentVersion: MHAppVersion,
        now: Date,
        maximumValidity: TimeInterval,
        policyLifetime: TimeInterval,
        publicationLifetime: TimeInterval
    ) -> MHRemoteUpdateDecision {
        switch document {
        case let .bounded(schedule):
            return MHRemoteUpdateSnapshot(
                schedule: schedule, storefront: storefront, publication: publication
            ).evaluate(
                currentVersion: currentVersion,
                now: now,
                maximumValidity: maximumValidity,
                maximumPublicationAge: publicationLifetime
            )
        case let .static(policy):
            guard observation?.isValid(at: now, maximumAge: policyLifetime) == true else {
                return .unavailable
            }
            guard let requirement = policy.requirement,
                  currentVersion < requirement.minimumVersion,
                  now >= requirement.effectiveAt,
                  requirement.endsAt.map({ now <= $0 }) != false else {
                return .notRequired
            }
            guard let publication, publication.isValid(at: now, maximumAge: publicationLifetime),
                  publication.version >= requirement.minimumVersion else {
                return .unavailable
            }
            return .updateRequired
        }
    }
}
