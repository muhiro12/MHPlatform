import Foundation

/// A small, coordinated evidence file at an app-selected location.
///
/// Use a separate URL for each app, environment, and storefront. Controllers and
/// processes using this store coordinate reads and revision-checked replacements.
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
        var result: Result<MHRemoteUpdateSnapshot?, any Error>?
        var error: NSError?
        NSFileCoordinator().coordinate(readingItemAt: fileURL, options: [], error: &error) { url in
            result = Result { try read(at: url) }
        }
        if let error {
            if error.code == NSFileReadNoSuchFileError, error.domain == NSCocoaErrorDomain {
                return nil
            }
            throw error
        }
        return try result?.get()
    }

    /// Rejects older or conflicting policy revisions while coordinating the complete replacement.
    public func save(_ snapshot: MHRemoteUpdateSnapshot) throws {
        _ = try retain(snapshot)
    }

    func retain(_ snapshot: MHRemoteUpdateSnapshot) throws -> MHRemoteUpdateSnapshot {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        var result: Result<MHRemoteUpdateSnapshot, any Error>?
        var error: NSError?
        NSFileCoordinator().coordinate(writingItemAt: fileURL, options: [], error: &error) { url in
            result = Result {
                let existing = try readableEvidence(at: url)
                let matchesIdentity = existing?.schedule.bundleIdentifier == snapshot.schedule.bundleIdentifier
                    && existing?.storefront == snapshot.storefront
                let merged = try matchesIdentity ? existing?.merging(snapshot) ?? snapshot : snapshot
                try write(merged, at: url)
                return merged
            }
        }
        if let error {
            throw error
        }
        guard let result else {
            throw CocoaError(.fileWriteUnknown)
        }
        return try result.get()
    }

    private func readableEvidence(at url: URL) throws -> MHRemoteUpdateSnapshot? {
        do {
            return try read(at: url)
        } catch is DecodingError {
            // A validated network response can repair an unreadable cache format.
            return nil
        } catch is MHRemoteUpdateSchedule.Failure {
            return nil
        } catch Failure.sourceMismatch {
            return nil
        }
    }

    private func read(at url: URL) throws -> MHRemoteUpdateSnapshot? {
        do {
            let data = try Data(contentsOf: url)
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

    private func write(_ snapshot: MHRemoteUpdateSnapshot, at url: URL) throws {
        let encoder = JSONEncoder()
        let data: Data
        if let sourceURL {
            data = try encoder.encode(ScopedSnapshot(sourceURL: sourceURL, snapshot: snapshot))
        } else {
            data = try encoder.encode(snapshot)
        }
        try data.write(to: url, options: .atomic)
    }
}
