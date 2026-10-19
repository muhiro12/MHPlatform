import Foundation

/// Keeps bounded-v1 and static-v2 meanings distinct, including revision identity.
enum MHRemoteUpdateDocument: Codable, Equatable, Sendable {
    case bounded(MHRemoteUpdateSchedule)
    case `static`(MHRemoteUpdateStaticPolicy)

    private struct Header: Decodable {
        let schemaVersion: Int
    }

    private static let staticSchemaVersion = 2

    var bundleIdentifier: String {
        switch self {
        case let .bounded(schedule):
            schedule.bundleIdentifier
        case let .static(policy):
            policy.bundleIdentifier
        }
    }

    var revision: Int {
        switch self {
        case let .bounded(schedule):
            schedule.revision
        case let .static(policy):
            policy.revision
        }
    }

    var requirement: MHRemoteUpdateSchedule.Requirement? {
        switch self {
        case let .bounded(schedule):
            schedule.requirement
        case let .static(policy):
            policy.requirement
        }
    }

    init(from decoder: any Decoder) throws {
        switch try Header(from: decoder).schemaVersion {
        case 1:
            self = .bounded(try MHRemoteUpdateSchedule(from: decoder))
        case Self.staticSchemaVersion:
            self = .static(try MHRemoteUpdateStaticPolicy(from: decoder))
        default:
            throw MHRemoteUpdateSchedule.Failure.unsupportedSchema
        }
    }

    func encode(to encoder: any Encoder) throws {
        switch self {
        case let .bounded(schedule):
            try schedule.encode(to: encoder)
        case let .static(policy):
            try policy.encode(to: encoder)
        }
    }

    func acceptsFetch(at date: Date, maximumValidity: TimeInterval) -> Bool {
        switch self {
        case let .bounded(schedule):
            schedule.isValid(at: date, maximumValidity: maximumValidity)
        case .static:
            date.timeIntervalSinceReferenceDate.isFinite
        }
    }
}
