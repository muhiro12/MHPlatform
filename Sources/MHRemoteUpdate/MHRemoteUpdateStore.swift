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

    private struct CacheHeader: Decodable {
        let cacheVersion: Int?
    }

    private struct StaticCache: Codable {
        let cacheVersion: Int
        let sourceURL: URL?
        let evidence: MHRemoteUpdateEvidence
    }

    private static let staticCacheVersion = 2

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

    /// Reads a bounded-v1 snapshot; static-v2 caches are restored through the controller.
    /// Returns nil only when absent; corruption and I/O errors remain observable.
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
        try write(data)
    }

    func loadEvidence() throws -> MHRemoteUpdateEvidence? {
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            if let version = try decoder.decode(CacheHeader.self, from: data).cacheVersion {
                let cache = try decoder.decode(StaticCache.self, from: data)
                guard version == Self.staticCacheVersion, case .static = cache.evidence.document else {
                    throw MHRemoteUpdateStaticPolicy.Failure.unsupportedSchema
                }
                guard cache.sourceURL == sourceURL else {
                    throw Failure.sourceMismatch
                }
                return cache.evidence
            }
            let snapshot: MHRemoteUpdateSnapshot
            if let sourceURL {
                let record = try decoder.decode(ScopedSnapshot.self, from: data)
                guard record.sourceURL == sourceURL else {
                    throw Failure.sourceMismatch
                }
                snapshot = record.snapshot
            } else {
                snapshot = try decoder.decode(MHRemoteUpdateSnapshot.self, from: data)
            }
            return .init(
                document: .bounded(snapshot.schedule),
                storefront: snapshot.storefront,
                observation: nil,
                publication: snapshot.publication
            )
        } catch CocoaError.fileReadNoSuchFile {
            return nil
        }
    }

    func saveEvidence(_ evidence: MHRemoteUpdateEvidence) throws {
        switch evidence.document {
        case let .bounded(schedule):
            try save(.init(schedule: schedule, storefront: evidence.storefront, publication: evidence.publication))
        case .static:
            try write(JSONEncoder().encode(StaticCache(
                cacheVersion: Self.staticCacheVersion, sourceURL: sourceURL, evidence: evidence
            )))
        }
    }

    private func write(_ data: Data) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try data.write(to: fileURL, options: .atomic)
    }
}
