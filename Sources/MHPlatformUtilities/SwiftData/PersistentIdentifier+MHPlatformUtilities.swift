import Foundation
import SwiftData

public extension PersistentIdentifier {
    /// Creates a persistent identifier by decoding a Base64-encoded JSON representation.
    /// - Parameter string: A Base64-encoded string created by ``base64Encoded()``.
    /// - Throws: `MHPersistentIdentifierCodecError.invalidBase64String`
    ///   when the input is not Base64, or a decoder error when the payload is invalid.
    init(base64Encoded string: String) throws {
        self = try MHPersistentIdentifierCodec.decode(string)
    }

    /// Encodes this identifier as JSON and returns a Base64-encoded string.
    /// - Returns: A Base64-encoded JSON string.
    func base64Encoded() throws -> String {
        try MHPersistentIdentifierCodec.encode(self)
    }
}
