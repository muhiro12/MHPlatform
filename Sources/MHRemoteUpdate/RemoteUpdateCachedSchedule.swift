import Foundation

// The cache retains its original date representation independently of the public Config wire format.
struct RemoteUpdateCachedSchedule: Codable {
    private enum CodingKeys: String, CodingKey {
        case schemaVersion, bundleIdentifier, revision, requirement, scheduledRequirements, issuedAt, validUntil
    }
    struct Requirement: Codable {
        let minimumVersion: MHAppVersion
        let effectiveAt: Date
        let endsAt: Date?

        var value: MHRemoteUpdateSchedule.Requirement {
            .init(minimumVersion: minimumVersion, effectiveAt: effectiveAt, endsAt: endsAt)
        }

        init(_ value: MHRemoteUpdateSchedule.Requirement) {
            minimumVersion = value.minimumVersion
            effectiveAt = value.effectiveAt
            endsAt = value.endsAt
        }
    }

    let schemaVersion: Int
    let bundleIdentifier: String
    let revision: Int
    let requirement: Requirement?
    let scheduledRequirements: [Requirement]

    init(_ value: MHRemoteUpdateSchedule) {
        schemaVersion = value.schemaVersion
        bundleIdentifier = value.bundleIdentifier
        revision = value.revision
        requirement = value.requirement.map(Requirement.init)
        scheduledRequirements = value.scheduledRequirements.map(Requirement.init)
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard container.contains(.requirement),
              container.contains(.issuedAt) == false,
              container.contains(.validUntil) == false else {
            throw MHRemoteUpdateSchedule.Failure.invalidDocument
        }
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        bundleIdentifier = try container.decode(String.self, forKey: .bundleIdentifier)
        revision = try container.decode(Int.self, forKey: .revision)
        requirement = try container.decodeIfPresent(Requirement.self, forKey: .requirement)
        scheduledRequirements = try container.contains(.scheduledRequirements)
            ? container.decode([Requirement].self, forKey: .scheduledRequirements) : []
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(bundleIdentifier, forKey: .bundleIdentifier)
        try container.encode(revision, forKey: .revision)
        try container.encode(requirement, forKey: .requirement)
        try container.encodeIfPresent(scheduledRequirements, forKey: .scheduledRequirements)
    }

    func schedule() throws -> MHRemoteUpdateSchedule {
        guard schemaVersion == 1 else {
            throw MHRemoteUpdateSchedule.Failure.unsupportedSchema
        }
        return try .init(
            bundleIdentifier: bundleIdentifier,
            revision: revision,
            requirement: requirement?.value,
            scheduledRequirements: scheduledRequirements.map(\.value)
        )
    }
}
