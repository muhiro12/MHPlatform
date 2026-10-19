import Foundation
import MHRemoteConfig

struct RemoteUpdateFeatures: Codable, Sendable {
    let remoteUpdate: MHRemoteUpdateSchedule.Feature
}

public extension MHRemoteUpdateSchedule {
    /// The independently revisioned `features.remoteUpdate` section.
    struct Feature: Codable, Equatable, Sendable {
        /// A positive immutable revision for update policy alone.
        public let revision: Int
        /// Explicit nil cancels; missing data never establishes cancellation.
        public let requirement: Requirement?

        /// Validates the update section without depending on other feature types.
        public init(revision: Int, requirement: Requirement?) throws {
            guard revision > 0 else {
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
            self.revision = revision
            self.requirement = requirement
        }

        /// Requires explicit cancellation and rejects publisher-controlled evidence expiry.
        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            guard container.contains(.requirement),
                  container.contains(.issuedAt) == false,
                  container.contains(.validUntil) == false else {
                throw Failure.invalidDocument
            }
            try self.init(
                revision: container.decode(Int.self, forKey: .revision),
                requirement: container.decodeIfPresent(Requirement.self, forKey: .requirement)
            )
        }

        /// Retains explicit nil rather than omitting cancellation.
        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(revision, forKey: .revision)
            try container.encode(requirement, forKey: .requirement)
        }
    }

    /// Selects validated update policy from a shared app configuration response.
    init(bundleIdentifier: String, feature: Feature) throws {
        try self.init(bundleIdentifier: bundleIdentifier, revision: feature.revision, requirement: feature.requirement)
    }

    /// Decodes only the update section of the shared app configuration envelope.
    static func decode(_ data: Data) throws -> Self {
        let document = try MHRemoteConfigDocument<RemoteUpdateFeatures>.decode(data)
        return try .init(bundleIdentifier: document.bundleIdentifier, feature: document.features.remoteUpdate)
    }

    /// Encodes an app configuration containing the update section.
    func encoded() throws -> Data {
        try MHRemoteConfigDocument(
            bundleIdentifier: bundleIdentifier,
            features: RemoteUpdateFeatures(remoteUpdate: .init(revision: revision, requirement: requirement))
        ).encoded()
    }
}

private extension MHRemoteUpdateSchedule.Feature {
    enum CodingKeys: String, CodingKey {
        case revision, requirement, issuedAt, validUntil
    }
}
