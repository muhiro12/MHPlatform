import Foundation
import MHRemoteConfig

struct RemoteUpdateFeatures: Codable, Sendable {
    let remoteUpdate: MHRemoteConfigSection<MHRemoteUpdateSchedule.Feature>
}

public extension MHRemoteUpdateSchedule {
    /// The independently revisioned `features.remoteUpdate` section.
    struct Feature: Codable, Equatable, Sendable {
        /// The update feature format, independent of policy revisions and the envelope.
        public let schemaVersion: Int
        /// A positive immutable revision for update policy alone.
        public let revision: Int
        /// Explicit nil removes the baseline; missing data never establishes cancellation.
        public let requirement: Requirement?
        /// Additional plans evaluated alongside the baseline after their activation.
        public let scheduledRequirements: [Requirement]

        /// Validates the update section without depending on other feature types.
        public init(revision: Int, requirement: Requirement?) throws {
            try self.init(revision: revision, requirement: requirement, scheduledRequirements: [])
        }

        /// Validates every plan before accepting any part of this update policy.
        public init(revision: Int, requirement: Requirement?, scheduledRequirements: [Requirement]) throws {
            guard revision > 0 else {
                throw Failure.invalidDocument
            }
            for candidate in requirement.map({ [$0] + scheduledRequirements }) ?? scheduledRequirements {
                guard candidate.effectiveAt.timeIntervalSinceReferenceDate.isFinite else {
                    throw Failure.invalidDocument
                }
                if let endsAt = candidate.endsAt {
                    guard endsAt.timeIntervalSinceReferenceDate.isFinite, endsAt > candidate.effectiveAt else {
                        throw Failure.invalidDocument
                    }
                }
            }
            schemaVersion = 1
            self.revision = revision
            self.requirement = requirement
            self.scheduledRequirements = scheduledRequirements
        }

        /// Requires explicit cancellation and rejects publisher-controlled evidence expiry.
        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let formatVersion = try container.contains(.schemaVersion)
                ? container.decode(Int.self, forKey: .schemaVersion) : 1
            guard formatVersion == 1 else {
                throw Failure.unsupportedSchema
            }
            guard container.contains(.requirement),
                  container.contains(.issuedAt) == false,
                  container.contains(.validUntil) == false else {
                throw Failure.invalidDocument
            }
            try self.init(
                revision: container.decode(Int.self, forKey: .revision),
                requirement: container.decodeIfPresent(Requirement.self, forKey: .requirement),
                scheduledRequirements: container.contains(.scheduledRequirements)
                    ? container.decode([Requirement].self, forKey: .scheduledRequirements) : []
            )
        }

        /// Retains explicit nil rather than omitting cancellation.
        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(schemaVersion, forKey: .schemaVersion)
            try container.encode(revision, forKey: .revision)
            try container.encode(requirement, forKey: .requirement)
            if scheduledRequirements.isEmpty == false {
                try container.encode(scheduledRequirements, forKey: .scheduledRequirements)
            }
        }
    }

    /// Selects validated update policy from a shared app configuration response.
    init(bundleIdentifier: String, feature: Feature) throws {
        try self.init(
            bundleIdentifier: bundleIdentifier,
            revision: feature.revision,
            requirement: feature.requirement,
            scheduledRequirements: feature.scheduledRequirements
        )
    }

    /// Decodes only the update section of the shared app configuration envelope.
    static func decode(_ data: Data) throws -> Self {
        try JSONDecoder().decode(Self.self, from: data)
    }

    /// Encodes an app configuration containing the update section.
    func encoded() throws -> Data {
        try configuration().encoded()
    }

    internal func configuration() throws -> MHRemoteConfigDocument<RemoteUpdateFeatures> {
        try MHRemoteConfigDocument(
            bundleIdentifier: bundleIdentifier,
            features: RemoteUpdateFeatures(remoteUpdate: .value(.init(
                revision: revision, requirement: requirement, scheduledRequirements: scheduledRequirements
            )))
        )
    }
}

private extension MHRemoteUpdateSchedule.Feature {
    enum CodingKeys: String, CodingKey {
        case schemaVersion, revision, requirement, scheduledRequirements, issuedAt, validUntil
    }
}
