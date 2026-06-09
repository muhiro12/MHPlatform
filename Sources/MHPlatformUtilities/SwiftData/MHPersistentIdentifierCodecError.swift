import Foundation

/// Errors thrown by `MHPersistentIdentifierCodec`.
public enum MHPersistentIdentifierCodecError: Error, Equatable, Sendable {
    /// The input string is not valid Base64 data.
    case invalidBase64String
}
