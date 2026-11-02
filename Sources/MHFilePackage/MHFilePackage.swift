import CryptoKit
import Foundation

/// Opt-in transport for app-owned directory formats, independent of record and manifest schemas.
public struct MHFilePackage: Sendable {
    /// A manifest-declared relative path and optional integrity evidence.
    public struct Reference: Sendable {
        /// Path including the app's asset directory.
        public let path: String
        /// Exact byte count when supplied by the manifest.
        public let byteCount: Int?
        /// Expected SHA-256 as 32 raw bytes when supplied by the manifest.
        public let sha256: Data?

        /// Describes one regular file named by the manifest.
        public init(path: String, byteCount: Int? = nil, sha256: Data? = nil) {
            self.path = path
            self.byteCount = byteCount
            self.sha256 = sha256
        }

        func verify(_ data: Data) throws {
            if let byteCount, data.count != byteCount {
                throw Failure.integrityMismatch
            }
            if let sha256, Data(SHA256.hash(data: data)) != sha256 {
                throw Failure.integrityMismatch
            }
        }
    }

    /// Detached bytes suitable for later review without provider access.
    public struct Snapshot: Sendable {
        /// Original manifest bytes, unchanged.
        public let manifest: Data
        /// Only the app-declared files, keyed by relative path.
        public let files: [String: Data]
    }

    /// Bounds apply on import and export, including packages containing many small files.
    public struct Limits: Sendable {
        let manifestBytes: Int
        let fileBytes: Int
        let totalFileBytes: Int
        let fileCount: Int

        /// Select finite limits appropriate to the app's format.
        public init(manifestBytes: Int, fileBytes: Int, totalFileBytes: Int, fileCount: Int) {
            self.manifestBytes = manifestBytes
            self.fileBytes = fileBytes
            self.totalFileBytes = totalFileBytes
            self.fileCount = fileCount
        }
    }

    /// Structural, budget, and integrity failures are separate from provider and app decoding errors.
    public enum Failure: Error {
        /// Invalid path, duplicate reference, or non-regular input.
        case invalidPackage
        /// A configured resource budget was exceeded.
        case limitExceeded
        /// Declared bytes or digest did not match.
        case integrityMismatch
    }

    let manifestName: String
    let assetDirectory: String
    let limits: Limits

    /// Uses the recommended layout by default. Existing formats can keep their published names.
    public init(limits: Limits, manifestName: String = "manifest.json", assetDirectory: String = "assets") throws {
        guard Self.validName(manifestName), Self.validName(assetDirectory),
              manifestName.caseInsensitiveCompare(assetDirectory) != .orderedSame else {
            throw Failure.invalidPackage
        }
        guard min(limits.manifestBytes, limits.fileBytes, limits.totalFileBytes, limits.fileCount) >= 0 else {
            throw Failure.limitExceeded
        }
        self.manifestName = manifestName
        self.assetDirectory = assetDirectory
        self.limits = limits
    }

    private static func validName(_ name: String) -> Bool {
        !name.isEmpty && name != "." && name != ".." && !name.contains("/")
            && !name.contains("\\") && !name.utf8.contains(0)
    }

    /// Builds a native package wrapper; callers own destination selection and atomic replacement.
    public func fileWrapper(manifest: Data, files: [String: Data]) throws -> FileWrapper {
        try Task.checkCancellation()
        guard manifest.count <= limits.manifestBytes, files.count <= limits.fileCount else {
            throw Failure.limitExceeded
        }
        let root = FileWrapper(directoryWithFileWrappers: [manifestName: .init(regularFileWithContents: manifest)])
        var remaining = limits.totalFileBytes
        for (path, data) in files {
            try Task.checkCancellation()
            let components = try assetPath(path)
            guard data.count <= min(limits.fileBytes, remaining) else {
                throw Failure.limitExceeded
            }
            remaining -= data.count
            var parent = root
            for component in components.dropLast() {
                if let existing = parent.fileWrappers?[component] {
                    guard existing.isDirectory else {
                        throw Failure.invalidPackage
                    }
                    parent = existing
                } else {
                    let directory = FileWrapper(directoryWithFileWrappers: [:])
                    try add(directory, named: component, to: parent)
                    parent = directory
                }
            }
            guard let filename = components.last else {
                throw Failure.invalidPackage
            }
            try add(.init(regularFileWithContents: data), named: filename, to: parent)
        }
        return root
    }

    func assetPath(_ path: String) throws -> [String] {
        let components = path.components(separatedBy: "/")
        guard components.count > 1, components.first == assetDirectory, components.allSatisfy(Self.validName) else {
            throw Failure.invalidPackage
        }
        return components
    }

    private func add(_ file: FileWrapper, named name: String, to parent: FileWrapper) throws {
        let names = parent.fileWrappers?.keys
        guard names?.contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) != true else {
            throw Failure.invalidPackage
        }
        file.preferredFilename = name
        guard parent.addFileWrapper(file) == name else {
            throw Failure.invalidPackage
        }
    }
}
