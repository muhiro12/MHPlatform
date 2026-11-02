import CryptoKit
import Foundation
import MHFilePackage
import Testing

struct FilePackageTests {
    private let bytes = Data("attachment".utf8)
    private let manifest = Data("[]".utf8)
    private let limits = MHFilePackage.Limits(manifestBytes: 32, fileBytes: 16, totalFileBytes: 20, fileCount: 3)

    @Test(arguments: ["assets", "photos"])
    func snapshotSurvivesRemovalAndIgnoresUnreferencedFiles(_ directory: String) async throws {
        let transport = try MHFilePackage(limits: limits, assetDirectory: directory)
        let path = directory + "/one.bin"
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }
        // The app's manifest owns the reference, not a recursive directory scan.
        let document = try JSONEncoder().encode([path])
        try transport.fileWrapper(manifest: document, files: [path: bytes])
            .write(to: url, options: .atomic, originalContentsURL: nil)
        try FileManager.default.createSymbolicLink(at: url.appending(path: "ignored"), withDestinationURL: url)
        let snapshot = try await transport.read(at: url) { manifest in
            try JSONDecoder().decode([String].self, from: manifest).map { path in
                .init(path: path, byteCount: bytes.count, sha256: Data(SHA256.hash(data: bytes)))
            }
        }
        try FileManager.default.removeItem(at: url)
        #expect(snapshot.manifest == document)
        #expect(snapshot.files == [path: bytes])
    }

    @Test
    func emptyPackageHasOnlyItsCustomManifest() async throws {
        let transport = try MHFilePackage(limits: limits, manifestName: "index.json")
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }
        try transport.fileWrapper(manifest: manifest, files: [:])
            .write(to: url, options: .atomic, originalContentsURL: nil)
        #expect(try FileManager.default.contentsOfDirectory(atPath: url.path) == ["index.json"])
        let snapshot = try await transport.read(at: url) { _ in [] }
        #expect(snapshot.manifest == manifest)
        #expect(snapshot.files.isEmpty)
    }

    @Test(arguments: ["../escape", "assets/../escape", "/assets/file", "assets//file", "assets/file\0other"])
    func traversalRejectedOnBothPaths(_ path: String) async throws {
        let (transport, url) = try package()
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(throws: MHFilePackage.Failure.invalidPackage) {
            try transport.fileWrapper(manifest: manifest, files: [path: bytes])
        }
        await #expect(throws: MHFilePackage.Failure.invalidPackage) {
            try await transport.read(at: url) { _ in [.init(path: path)] }
        }
    }

    @Test(arguments: ["manifest.json", "assets", "assets/file"])
    func rejectsSymlinksAtEveryDepth(_ path: String) async throws {
        let (transport, url) = try package()
        let outside = temporaryURL()
        defer {
            try? FileManager.default.removeItem(at: url)
            try? FileManager.default.removeItem(at: outside)
        }
        let source = url.appending(path: path)
        try FileManager.default.moveItem(at: source, to: outside)
        try FileManager.default.createSymbolicLink(at: source, withDestinationURL: outside)
        await #expect(throws: (any Error).self) {
            try await transport.read(at: url) { _ in [.init(path: "assets/file")] }
        }
    }

    @Test
    func refusesIntegrityAndBudgetFailures() async throws {
        let (transport, url) = try package()
        defer { try? FileManager.default.removeItem(at: url) }
        for reference in [
            MHFilePackage.Reference(path: "assets/file", byteCount: 1),
            .init(path: "assets/file", sha256: Data())
        ] {
            await #expect(throws: MHFilePackage.Failure.integrityMismatch) {
                try await transport.read(at: url) { _ in [reference] }
            }
        }
        let oversized = Data(count: 33)
        try oversized.write(to: url.appending(path: "assets/file"))
        await #expect(throws: MHFilePackage.Failure.limitExceeded) {
            try await transport.read(at: url) { _ in [.init(path: "assets/file")] }
        }
        try oversized.write(to: url.appending(path: "manifest.json"))
        await #expect(throws: MHFilePackage.Failure.limitExceeded) {
            try await transport.read(at: url) { _ in
                Issue.record("Oversized manifest reached the decoder")
                return []
            }
        }
    }

    @Test
    func aggregateBudgetsApplyAcrossIndividuallyValidFiles() async throws {
        let (transport, url) = try package()
        defer { try? FileManager.default.removeItem(at: url) }
        let extra = Data(count: 12)
        try extra.write(to: url.appending(path: "assets/extra"))
        await #expect(throws: MHFilePackage.Failure.limitExceeded) {
            try await transport.read(at: url) { _ in [.init(path: "assets/file"), .init(path: "assets/extra")] }
        }
        #expect(throws: MHFilePackage.Failure.limitExceeded) {
            try transport.fileWrapper(manifest: manifest, files: ["assets/file": bytes, "assets/extra": extra])
        }
        await #expect(throws: MHFilePackage.Failure.limitExceeded) {
            try await transport.read(at: url) { _ in Array(repeating: .init(path: "assets/file"), count: 4) }
        }
    }

    @Test
    func cancellationDuringManifestReviewCannotReturnBytes() async throws {
        let (transport, url) = try package()
        defer { try? FileManager.default.removeItem(at: url) }
        let task = Task {
            try await transport.read(at: url) { _ in
                withUnsafeCurrentTask { $0?.cancel() }
                return [.init(path: "assets/file")]
            }
        }
        await #expect(throws: CancellationError.self) { try await task.value }
    }

    private func temporaryURL() -> URL {
        FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    }

    private func package() throws -> (MHFilePackage, URL) {
        let transport = try MHFilePackage(limits: limits)
        let url = temporaryURL()
        try transport.fileWrapper(manifest: manifest, files: ["assets/file": bytes])
            .write(to: url, options: .atomic, originalContentsURL: nil)
        return (transport, url)
    }
}
