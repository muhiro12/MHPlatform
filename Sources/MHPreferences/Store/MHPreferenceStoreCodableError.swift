import Foundation

/// Failure reported by explicit `Codable` preference result APIs.
public enum MHPreferenceStoreCodableError: Error, Equatable, Sendable {
    /// A value exists for the key but is not stored as `Data`.
    case storedValueIsNotData(storageKey: String)
    /// The stored `Data` could not be decoded into the requested value type.
    case decodingFailed(storageKey: String, description: String)
    /// The supplied value could not be encoded before storage.
    case encodingFailed(storageKey: String, description: String)
}

extension MHPreferenceStoreCodableError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .storedValueIsNotData(storageKey):
            return "Stored value is not Data for key \(storageKey)."
        case let .decodingFailed(storageKey, description):
            return "Failed to decode value for key \(storageKey): \(description)"
        case let .encodingFailed(storageKey, description):
            return "Failed to encode value for key \(storageKey): \(description)"
        }
    }
}
