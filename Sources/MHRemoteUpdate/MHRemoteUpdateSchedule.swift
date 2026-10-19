import Foundation

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
                effectiveAt: try container.decode(Date.self, forKey: .effectiveAt),
                endsAt: try container.decodeIfPresent(Date.self, forKey: .endsAt)
            )
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
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, bundleIdentifier, revision, requirement, scheduledRequirements, issuedAt, validUntil
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

    /// Rejects authored expiry fields; freshness belongs to fetched evidence.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        bundleIdentifier = try container.decode(String.self, forKey: .bundleIdentifier)
        revision = try container.decode(Int.self, forKey: .revision)
        guard container.contains(.requirement),
              container.contains(.issuedAt) == false,
              container.contains(.validUntil) == false else {
            throw Failure.invalidDocument
        }
        requirement = try container.decodeIfPresent(Requirement.self, forKey: .requirement)
        scheduledRequirements = container.contains(.scheduledRequirements)
            ? try container.decode([Requirement].self, forKey: .scheduledRequirements) : []
        try validate()
    }

    private static func canonicalDate(_ date: Date) -> Date {
        .init(timeIntervalSinceReferenceDate: date.timeIntervalSinceReferenceDate.rounded(.down))
    }

    /// Encodes explicit cancellation without any publisher-controlled expiry.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(bundleIdentifier, forKey: .bundleIdentifier)
        try container.encode(revision, forKey: .revision)
        try container.encode(requirement, forKey: .requirement)
        if scheduledRequirements.isEmpty == false {
            try container.encode(scheduledRequirements, forKey: .scheduledRequirements)
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
