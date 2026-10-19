/// Request, document, and identity validation failures shared by remote configuration features.
public enum MHRemoteConfigError: Error, Equatable, Sendable {
    /// A secure endpoint and nonempty expected app identity are required.
    case invalidRequest
    /// Configuration must come from an HTTP response.
    case invalidResponse
    /// The server returned a status outside 200 through 299.
    case httpStatus(Int)
    /// The configuration envelope uses an unsupported format.
    case unsupportedSchema
    /// The envelope has an invalid app identity.
    case invalidDocument
    /// The configuration belongs to a different app.
    case identityMismatch
}
