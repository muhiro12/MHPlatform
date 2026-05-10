import Foundation

/// Small helpers for building structured log metadata dictionaries.
public enum MHLogMetadata {
    /// Creates metadata from key/value pairs, dropping nil values.
    public static func metadata(
        _ entries: (String, String?)...
    ) -> [String: String] {
        metadata(entries)
    }

    /// Creates metadata from key/value pairs, dropping nil values.
    public static func metadata(
        _ entries: [(String, String?)]
    ) -> [String: String] {
        var values = [String: String]()

        for (key, value) in entries {
            guard let value else {
                continue
            }
            values[key] = value
        }

        return values
    }

    /// Merges metadata dictionaries from left to right.
    public static func merge(
        _ metadataValues: [String: String]...
    ) -> [String: String] {
        metadataValues.reduce(into: [String: String]()) { result, metadata in
            result.merge(metadata) { _, newValue in
                newValue
            }
        }
    }

    /// Creates boolean metadata with stable lowercase values.
    public static func bool(
        _ key: String,
        _ value: Bool
    ) -> [String: String] {
        [key: value ? "true" : "false"]
    }

    /// Creates count metadata.
    public static func count(
        _ key: String,
        _ value: Int
    ) -> [String: String] {
        [key: String(value)]
    }

    /// Creates presence metadata for an optional value.
    public static func presence<Value>(
        _ key: String,
        _ value: Value?
    ) -> [String: String] {
        [key: value == nil ? "missing" : "present"]
    }

    /// Creates metadata for an error without defining app-owned error policy.
    public static func errorMetadata(
        _ error: any Error,
        errorKey: String = "error",
        typeKey: String = "errorType"
    ) -> [String: String] {
        metadata(
            (errorKey, error.localizedDescription),
            (typeKey, String(describing: type(of: error)))
        )
    }
}
