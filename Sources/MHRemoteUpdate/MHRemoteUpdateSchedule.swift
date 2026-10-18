import Foundation

/// A versioned operational document independent of an app's source release.
///
/// Dates are normalized down to whole seconds for the ISO 8601 wire format.
/// Every revision is immutable; cancellation is a higher revision with an
/// explicit `requirement: null`.
public struct MHRemoteUpdateSchedule: Codable, Equatable, Sendable {
    /// A future or active minimum version. Publication confirmation is always required.
    public struct Requirement: Codable, Equatable, Sendable {
        /// The oldest installed version accepted after activation.
        public let minimumVersion: MHAppVersion
        /// The first instant at which the requirement applies.
        public let effectiveAt: Date
        /// An optional inclusive end; independent of the document's validity.
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

    /// Validation failures for remote documents and their expected app identity.
    public enum Failure: Error, Equatable, Sendable {
        /// The schema version is unsupported.
        case unsupportedSchema
        /// Identity, revision, or dates are invalid.
        case invalidDocument
        /// The document belongs to another app.
        case identityMismatch
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, bundleIdentifier, revision, issuedAt, validUntil, requirement
    }

    /// The supported wire format version.
    public let schemaVersion: Int
    /// The app to which this document applies.
    public let bundleIdentifier: String
    /// A positive, monotonically increasing policy revision, unrelated to app versions.
    public let revision: Int
    /// The earliest instant at which this document can be trusted.
    public let issuedAt: Date
    /// The exclusive expiry of the entire document, including a cancellation.
    public let validUntil: Date
    /// An explicit absence means a confirmed lack of an update requirement.
    public let requirement: Requirement?

    /// Creates a validated schedule without choosing release values or lifetimes.
    public init(
        bundleIdentifier: String,
        revision: Int,
        issuedAt: Date,
        validUntil: Date,
        requirement: Requirement?
    ) throws {
        schemaVersion = 1
        self.bundleIdentifier = bundleIdentifier
        self.revision = revision
        self.issuedAt = Self.canonicalDate(issuedAt)
        self.validUntil = Self.canonicalDate(validUntil)
        self.requirement = requirement
        try validate()
    }

    /// Rejects missing requirement keys; only explicit null cancels a requirement.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        bundleIdentifier = try container.decode(String.self, forKey: .bundleIdentifier)
        revision = try container.decode(Int.self, forKey: .revision)
        issuedAt = Self.canonicalDate(try container.decode(Date.self, forKey: .issuedAt))
        validUntil = Self.canonicalDate(try container.decode(Date.self, forKey: .validUntil))
        guard container.contains(.requirement) else {
            throw Failure.invalidDocument
        }
        requirement = try container.decodeIfPresent(Requirement.self, forKey: .requirement)
        try validate()
    }

    /// Decodes the shared wire format; deployment URLs remain app-owned.
    public static func decode(_ data: Data) throws -> Self {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Self.self, from: data)
    }

    private static func canonicalDate(_ date: Date) -> Date {
        .init(timeIntervalSinceReferenceDate: date.timeIntervalSinceReferenceDate.rounded(.down))
    }

    /// Encodes explicit null for cancellation so it cannot be confused with omission.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(bundleIdentifier, forKey: .bundleIdentifier)
        try container.encode(revision, forKey: .revision)
        try container.encode(issuedAt, forKey: .issuedAt)
        try container.encode(validUntil, forKey: .validUntil)
        try container.encode(requirement, forKey: .requirement)
    }

    /// Encodes the shared remote format for independently published policy documents.
    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    func isValid(at date: Date, maximumValidity: TimeInterval) -> Bool {
        date.timeIntervalSinceReferenceDate.isFinite
            && maximumValidity.isFinite && maximumValidity > 0
            && validUntil.timeIntervalSince(issuedAt) <= maximumValidity
            && issuedAt <= date && date < validUntil
    }

    private func validate() throws {
        guard schemaVersion == 1 else {
            throw Failure.unsupportedSchema
        }
        guard bundleIdentifier.isEmpty == false,
              bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines) == bundleIdentifier,
              revision > 0,
              issuedAt.timeIntervalSinceReferenceDate.isFinite,
              validUntil.timeIntervalSinceReferenceDate.isFinite,
              validUntil > issuedAt,
              validUntil.timeIntervalSince(issuedAt).isFinite else {
            throw Failure.invalidDocument
        }
        if let requirement {
            guard requirement.effectiveAt.timeIntervalSinceReferenceDate.isFinite,
                  requirement.effectiveAt < validUntil else {
                throw Failure.invalidDocument
            }
            if let endsAt = requirement.endsAt {
                guard endsAt.timeIntervalSinceReferenceDate.isFinite,
                      endsAt > requirement.effectiveAt else {
                    throw Failure.invalidDocument
                }
            }
        }
    }
}

private extension MHRemoteUpdateSchedule.Requirement {
    enum CodingKeys: String, CodingKey {
        case minimumVersion, effectiveAt, endsAt
    }
}
