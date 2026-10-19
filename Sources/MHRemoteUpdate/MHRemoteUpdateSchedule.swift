import Foundation
import MHRemoteConfig

/// An immutable release decision with no publisher renewal deadline.
///
/// Only a validated fetch renews the controller's separate, bounded evidence.
/// Activation dates remain absolute. Use a higher revision for every policy change.
public struct MHRemoteUpdateSchedule: Codable, Equatable, Sendable {
    /// A future or active minimum version. Publication confirmation is always required.
    public struct Requirement: Codable, Equatable, Sendable {
        /// The oldest installed version accepted after activation.
        public let minimumVersion: MHAppVersion
        /// The first instant at which the requirement applies.
        public let effectiveAt: Date
        /// An optional inclusive end; independent of retained-evidence freshness.
        public let endsAt: Date?

        /// Creates a requirement; the containing schedule validates its dates.
        public init(minimumVersion: MHAppVersion, effectiveAt: Date, endsAt: Date? = nil) {
            self.minimumVersion = minimumVersion
            self.effectiveAt = MHRemoteUpdateSchedule.canonicalDate(effectiveAt)
            self.endsAt = endsAt.map(MHRemoteUpdateSchedule.canonicalDate)
        }

        /// Applies the same wire precision when restoring or decoding a requirement.
        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.init(
                minimumVersion: try container.decode(MHAppVersion.self, forKey: .minimumVersion),
                effectiveAt: try Date(container.decode(String.self, forKey: .effectiveAt), strategy: .iso8601),
                endsAt: try container.decodeIfPresent(String.self, forKey: .endsAt).map { value in
                    try Date(value, strategy: .iso8601)
                }
            )
        }

        /// Uses the same ISO 8601 wire dates regardless of the encoder's date strategy.
        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(minimumVersion, forKey: .minimumVersion)
            try container.encode(effectiveAt.formatted(.iso8601), forKey: .effectiveAt)
            try container.encodeIfPresent(endsAt?.formatted(.iso8601), forKey: .endsAt)
        }
    }

    /// Validation failures for static policy documents.
    public enum Failure: Error, Equatable, Sendable {
        /// The wire schema version is unsupported.
        case unsupportedSchema
        /// Identity, revision, requirement presence, or activation dates are invalid.
        case invalidDocument
        /// The document belongs to another app.
        case identityMismatch
        /// A policy revision moved backwards or changed immutable content.
        case revisionConflict
    }

    private static let supportedSchemaVersion = 1

    /// The static wire format version.
    public let schemaVersion: Int
    /// The app whose release policy this document describes.
    public let bundleIdentifier: String
    /// A positive immutable revision, independent of the app version.
    public let revision: Int
    /// The baseline requirement; explicit nil removes it, while omission in JSON is invalid.
    public let requirement: Requirement?
    /// Additional independently timed requirements; active requirements cannot weaken the baseline.
    public let scheduledRequirements: [Requirement]

    var allRequirements: [Requirement] {
        requirement.map { [$0] + scheduledRequirements } ?? scheduledRequirements
    }

    /// Creates a policy; only its fetched evidence receives an expiry.
    public init(
        bundleIdentifier: String,
        revision: Int,
        requirement: Requirement?
    ) throws {
        try self.init(
            bundleIdentifier: bundleIdentifier, revision: revision, requirement: requirement, scheduledRequirements: []
        )
    }

    /// Adds plans without replacing a currently enforced minimum.
    ///
    /// The highest minimum among all active requirements applies. Removing or
    /// postponing a plan requires a higher revision of the complete policy.
    public init(
        bundleIdentifier: String,
        revision: Int,
        requirement: Requirement?,
        scheduledRequirements: [Requirement]
    ) throws {
        schemaVersion = Self.supportedSchemaVersion
        self.bundleIdentifier = bundleIdentifier
        self.revision = revision
        self.requirement = requirement
        self.scheduledRequirements = scheduledRequirements
        try validate()
    }

    /// Decodes the shared envelope, matching `decode(_:)` and the standard Config client.
    public init(from decoder: any Decoder) throws {
        let document = try MHRemoteConfigDocument<RemoteUpdateFeatures>(from: decoder)
        try self.init(bundleIdentifier: document.bundleIdentifier, feature: document.features.remoteUpdate.get())
    }

    private static func canonicalDate(_ date: Date) -> Date {
        .init(timeIntervalSinceReferenceDate: date.timeIntervalSinceReferenceDate.rounded(.down))
    }

    /// Encodes the shared envelope rather than a persistence-specific schedule shape.
    public func encode(to encoder: any Encoder) throws {
        try configuration().encode(to: encoder)
    }

    /// Validates an entire replacement using the same immutable revisions as retained evidence.
    ///
    /// Identical policy is allowed at the same revision. Cancellation, postponement,
    /// and every other policy change require a higher revision for the same app.
    public func validateReplacement(of previous: Self) throws {
        guard bundleIdentifier == previous.bundleIdentifier else {
            throw Failure.identityMismatch
        }
        guard revision >= previous.revision, revision != previous.revision || self == previous else {
            throw Failure.revisionConflict
        }
    }

    func minimumVersion(at date: Date) -> MHAppVersion? {
        allRequirements.lazy.filter { requirement in
            date >= requirement.effectiveAt && requirement.endsAt.map { date <= $0 } != false
        }
        .map(\.minimumVersion)
        .max()
    }

    func needsPublication(currentVersion: MHAppVersion, at date: Date) -> Bool {
        allRequirements.contains { requirement in
            currentVersion < requirement.minimumVersion && requirement.endsAt.map { date <= $0 } != false
        }
    }

    private func validate() throws {
        guard schemaVersion == Self.supportedSchemaVersion else {
            throw Failure.unsupportedSchema
        }
        guard bundleIdentifier.isEmpty == false,
              bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines) == bundleIdentifier else {
            throw Failure.invalidDocument
        }
        _ = try Feature(revision: revision, requirement: requirement, scheduledRequirements: scheduledRequirements)
    }
}

private extension MHRemoteUpdateSchedule.Requirement {
    enum CodingKeys: String, CodingKey {
        case minimumVersion, effectiveAt, endsAt
    }
}
