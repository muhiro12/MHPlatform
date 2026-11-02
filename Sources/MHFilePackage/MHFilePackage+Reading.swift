import Darwin
import Foundation

extension MHFilePackage {
    private static let chunkBytes = 65_536

    /// Coordinates one read, letting the adopter validate the manifest/version before opening assets.
    /// Returned data owns its bytes; no URL or file handle escapes the security scope.
    @preconcurrency
    @concurrent
    public func read(
        at url: URL,
        references: @Sendable (Data) throws -> [Reference]
    ) async throws -> Snapshot {
        try Task.checkCancellation()
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        guard url.isFileURL, !url.path.utf8.contains(0),
              try url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink != true else {
            throw Failure.invalidPackage
        }
        var coordinationError: NSError?
        var result: Result<Snapshot, any Error>?
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError) { coordinated in
            result = Result {
                try readCoordinated(at: coordinated, references: references)
            }
        }
        try Task.checkCancellation()
        if let coordinationError {
            throw coordinationError
        }
        guard let result else {
            throw Failure.invalidPackage
        }
        return try result.get()
    }

    private func readCoordinated(at url: URL, references: (Data) throws -> [Reference]) throws -> Snapshot {
        try Task.checkCancellation()
        let directory = open(url.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard directory >= 0 else {
            throw POSIXError(.init(rawValue: errno) ?? .EIO)
        }
        defer { close(directory) }
        let manifest = try readFile([manifestName], in: directory, limit: limits.manifestBytes)
        let entries = try references(manifest)
        guard entries.count <= limits.fileCount else {
            throw Failure.limitExceeded
        }
        var files = [String: Data]()
        var remaining = limits.totalFileBytes
        for entry in entries {
            try Task.checkCancellation()
            let path = try assetPath(entry.path)
            guard files[entry.path] == nil else {
                throw Failure.invalidPackage
            }
            let limit = min(limits.fileBytes, remaining)
            if let count = entry.byteCount, !(0...limit).contains(count) {
                throw Failure.limitExceeded
            }
            let data = try readFile(path, in: directory, limit: limit)
            try entry.verify(data)
            remaining -= data.count
            files[entry.path] = data
        }
        return .init(manifest: manifest, files: files)
    }

    // Resolve each component relative to an open directory. A rename cannot redirect
    // a later open through a previously checked symlink.
    private func readFile(_ path: [String], in root: Int32, limit: Int) throws -> Data {
        var descriptor = dup(root)
        guard descriptor >= 0 else {
            throw POSIXError(.init(rawValue: errno) ?? .EIO)
        }
        defer { close(descriptor) }
        for (index, name) in path.enumerated() {
            let flags = O_RDONLY | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK
            let child = openat(descriptor, name, index == path.count - 1 ? flags : flags | O_DIRECTORY)
            guard child >= 0 else {
                throw POSIXError(.init(rawValue: errno) ?? .EIO)
            }
            close(descriptor)
            descriptor = child
        }
        var metadata = stat()
        guard fstat(descriptor, &metadata) == 0, metadata.st_mode & S_IFMT == S_IFREG else {
            throw Failure.invalidPackage
        }
        guard metadata.st_size <= limit else {
            throw Failure.limitExceeded
        }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: false)
        let chunkSize = Self.chunkBytes
        var bytes = Data()
        while true {
            try Task.checkCancellation()
            // One extra byte detects growth without allocating to the declared limit.
            let remaining = limit - bytes.count
            let count = remaining >= chunkSize ? chunkSize : remaining + 1
            guard let chunk = try handle.read(upToCount: count), !chunk.isEmpty else {
                return bytes
            }
            guard chunk.count <= remaining else {
                throw Failure.limitExceeded
            }
            bytes.append(chunk)
        }
    }
}
