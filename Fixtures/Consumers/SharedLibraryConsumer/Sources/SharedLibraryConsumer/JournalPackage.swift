import Foundation
import MHFilePackage

/// Only the adopter interprets the document version and attachment metadata.
enum JournalPackage {
    struct Manifest: Codable {
        let version: Int
        let attachment: String?
    }

    private static let manifestBytes = 16_384
    private static let fileBytes = 262_144
    private static let totalFileBytes = 1_048_576
    private static let fileCount = 8

    static func read(at url: URL) async throws -> MHFilePackage.Snapshot {
        let transport = try MHFilePackage(limits: .init(
            manifestBytes: manifestBytes, fileBytes: fileBytes, totalFileBytes: totalFileBytes, fileCount: fileCount
        ))
        return try await transport.read(at: url) { bytes in
            let document = try JSONDecoder().decode(Manifest.self, from: bytes)
            guard document.version == 1 else {
                throw CocoaError(.fileReadUnknown)
            }
            return document.attachment.map { [.init(path: $0)] } ?? []
        }
    }
}
