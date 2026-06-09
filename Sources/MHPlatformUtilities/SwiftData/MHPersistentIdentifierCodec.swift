import Foundation
import SwiftData

/// Encodes and decodes SwiftData persistent identifiers as stable strings.
public enum MHPersistentIdentifierCodec {
    /// Decodes a Base64 string into a `PersistentIdentifier`.
    /// - Parameter string: A Base64-encoded JSON representation.
    /// - Returns: The decoded persistent identifier.
    /// - Throws: `MHPersistentIdentifierCodecError.invalidBase64String`
    ///   when the input is not Base64, or a decoder error when the payload is invalid.
    public static func decode(
        _ string: String
    ) throws -> PersistentIdentifier {
        guard let data = Data(base64Encoded: string) else {
            throw MHPersistentIdentifierCodecError.invalidBase64String
        }
        return try JSONDecoder().decode(PersistentIdentifier.self, from: data)
    }

    /// Encodes a persistent identifier into a stable Base64 string.
    /// - Parameter identifier: The identifier to encode.
    /// - Returns: A Base64-encoded JSON representation.
    public static func encode(
        _ identifier: PersistentIdentifier
    ) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(identifier).base64EncodedString()
    }

    /// Encodes a persistent identifier into a stable string when possible.
    /// - Parameter identifier: The identifier to encode.
    /// - Returns: A stable string, or `nil` when encoding fails.
    public static func encodeIfPossible(
        _ identifier: PersistentIdentifier
    ) -> String? {
        try? encode(identifier)
    }

    /// Returns a stable identifier for a persistent model.
    ///
    /// When encoding fails, the method falls back to SwiftData's textual
    /// identifier description so callers can still provide a deterministic
    /// value for UI identity or payload assembly.
    /// - Parameter model: The model whose identifier should be converted.
    /// - Returns: A stable identifier string.
    public static func stableIdentifier<Model>(
        for model: Model
    ) -> String where Model: PersistentModel {
        if let encodedIdentifier = encodeIfPossible(model.persistentModelID) {
            return encodedIdentifier
        }
        return String(describing: model.persistentModelID)
    }
}
