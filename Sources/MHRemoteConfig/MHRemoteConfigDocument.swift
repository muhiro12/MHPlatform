import Foundation

/// A common app identity and typed feature payload, independent of feature-specific policy.
///
/// Decode all selected features once and share the resulting value. Features own
/// their revisions, validation, freshness, and failure behavior; adding a sibling
/// feature does not change the envelope or a previously accepted feature revision.
/// Wrap each selected feature in `MHRemoteConfigSection` to isolate its failure.
public struct MHRemoteConfigDocument<Features: Decodable & Sendable>: Decodable, Sendable {
    private enum CodingKeys: String, CodingKey {
        case schemaVersion, bundleIdentifier, features
    }

    /// The shared configuration envelope format.
    public let schemaVersion: Int
    /// The app whose configuration this document contains.
    public let bundleIdentifier: String
    /// Feature-specific configuration selected by the consumer's decoding type.
    public let features: Features

    /// Creates an envelope without selecting an endpoint or imposing feature policy.
    public init(bundleIdentifier: String, features: Features) throws {
        schemaVersion = 1
        self.bundleIdentifier = bundleIdentifier
        self.features = features
        try Self.validateIdentity(bundleIdentifier)
    }

    /// Validates the envelope before decoding its selected features.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        bundleIdentifier = try container.decode(String.self, forKey: .bundleIdentifier)
        guard schemaVersion == 1 else {
            throw MHRemoteConfigError.unsupportedSchema
        }
        try Self.validateIdentity(bundleIdentifier)
        features = try container.decode(Features.self, forKey: .features)
    }

    /// Decodes the envelope and selected features using ISO 8601 dates.
    public static func decode(_ data: Data) throws -> Self {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Self.self, from: data)
    }

    private static func validateIdentity(_ identity: String) throws {
        guard identity.isEmpty == false,
              identity.trimmingCharacters(in: .whitespacesAndNewlines) == identity else {
            throw MHRemoteConfigError.invalidDocument
        }
    }
}

extension MHRemoteConfigDocument: Encodable where Features: Encodable {
    /// Encodes the shared envelope without inventing publisher renewal timestamps.
    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }
}
