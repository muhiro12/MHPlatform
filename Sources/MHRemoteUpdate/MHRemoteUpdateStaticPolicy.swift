import Foundation

/// An immutable schema-v2 release decision with no publisher renewal deadline.
///
/// Only a validated fetch renews the controller's separate, bounded evidence.
/// Activation dates remain absolute. Use a higher revision for every policy change.
public struct MHRemoteUpdateStaticPolicy: Codable, Equatable, Sendable {
    /// Validation failures for static policy documents.
    public enum Failure: Error, Equatable, Sendable {
        /// Only schema version 2 describes a static policy.
        case unsupportedSchema
        /// Identity, revision, requirement presence, or activation dates are invalid.
        case invalidDocument
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, bundleIdentifier, revision, requirement, issuedAt, validUntil
    }

    private static let staticSchemaVersion = 2

    /// The static wire format version.
    public let schemaVersion: Int
    /// The app whose release policy this document describes.
    public let bundleIdentifier: String
    /// A positive immutable revision, independent of the app version.
    public let revision: Int
    /// An explicit nil cancels the requirement; omission in JSON is invalid.
    public let requirement: MHRemoteUpdateSchedule.Requirement?

    /// Creates a policy; only its fetched evidence receives an expiry.
    public init(
        bundleIdentifier: String,
        revision: Int,
        requirement: MHRemoteUpdateSchedule.Requirement?
    ) throws {
        schemaVersion = Self.staticSchemaVersion
        self.bundleIdentifier = bundleIdentifier
        self.revision = revision
        self.requirement = requirement
        try validate()
    }

    /// Rejects bounded-document timestamps rather than silently ignoring their meaning.
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
        requirement = try container.decodeIfPresent(MHRemoteUpdateSchedule.Requirement.self, forKey: .requirement)
        try validate()
    }

    /// Decodes ISO 8601 UTC seconds, matching the bounded schedule's activation format.
    public static func decode(_ data: Data) throws -> Self {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Self.self, from: data)
    }

    /// Encodes explicit cancellation without any publisher-controlled expiry.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(bundleIdentifier, forKey: .bundleIdentifier)
        try container.encode(revision, forKey: .revision)
        try container.encode(requirement, forKey: .requirement)
    }

    /// Encodes the independently hosted static policy.
    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    private func validate() throws {
        guard schemaVersion == Self.staticSchemaVersion else {
            throw Failure.unsupportedSchema
        }
        guard bundleIdentifier.isEmpty == false,
              bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines) == bundleIdentifier,
              revision > 0 else {
            throw Failure.invalidDocument
        }
        if let requirement {
            guard requirement.effectiveAt.timeIntervalSinceReferenceDate.isFinite else {
                throw Failure.invalidDocument
            }
            if let endsAt = requirement.endsAt {
                guard endsAt.timeIntervalSinceReferenceDate.isFinite, endsAt > requirement.effectiveAt else {
                    throw Failure.invalidDocument
                }
            }
        }
    }
}
