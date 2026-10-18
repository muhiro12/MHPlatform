import Foundation

/// A small, atomically replaced evidence file at an app-selected location.
///
/// Use a separate URL for each app, environment, and storefront. One controller
/// owns each file; coordinating writers in multiple processes is app-owned.
public struct MHRemoteUpdateStore: Sendable {
    /// Validation failure for standard-integration cache files.
    public enum Failure: Error, Equatable, Sendable {
        /// Retained policy came from a different deployment endpoint.
        case sourceMismatch
    }

    private struct ScopedSnapshot: Codable {
        let sourceURL: URL
        let snapshot: MHRemoteUpdateSnapshot
    }

    private let fileURL: URL
    private let sourceURL: URL?

    /// Uses the supplied file URL, creating parent directories when saving.
    public init(fileURL: URL) {
        self.fileURL = fileURL
        sourceURL = nil
    }

    init(fileURL: URL, sourceURL: URL) {
        self.fileURL = fileURL
        self.sourceURL = sourceURL
    }

    /// Returns nil only when the file is absent; corruption and I/O errors remain observable.
    public func load() throws -> MHRemoteUpdateSnapshot? {
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            if let sourceURL {
                let record = try decoder.decode(ScopedSnapshot.self, from: data)
                guard record.sourceURL == sourceURL else {
                    throw Failure.sourceMismatch
                }
                return record.snapshot
            }
            return try decoder.decode(MHRemoteUpdateSnapshot.self, from: data)
        } catch CocoaError.fileReadNoSuchFile {
            return nil
        }
    }

    /// Writes before replacing the old file; never removes evidence on fetch failure.
    public func save(_ snapshot: MHRemoteUpdateSnapshot) throws {
        let encoder = JSONEncoder()
        let data: Data
        if let sourceURL {
            data = try encoder.encode(ScopedSnapshot(sourceURL: sourceURL, snapshot: snapshot))
        } else {
            data = try encoder.encode(snapshot)
        }
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try data.write(to: fileURL, options: .atomic)
    }
}
