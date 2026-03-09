import Foundation

/// JSON Lines sink with a single-archive rotation strategy.
public actor MHJSONLLogSink: MHLogSink {
    private let fileURL: URL
    private let archivedFileURL: URL
    private let maximumFileSizeBytes: Int
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(
        fileURL: URL,
        maximumFileSizeBytes: Int,
        fileManager: FileManager = .default
    ) {
        self.fileURL = fileURL
        self.archivedFileURL = fileURL.appendingPathExtension("1")
        self.maximumFileSizeBytes = max(maximumFileSizeBytes, 1)
        self.fileManager = fileManager
        self.encoder = MHLogJSONCodec.makeEncoder()
        self.decoder = MHLogJSONCodec.makeDecoder()
    }

    public func write(_ event: MHLogEvent) async {
        await Task.yield()

        do {
            try ensureParentDirectoryExists()
            let lineData = try encodedLineData(for: event)
            try rotateIfNeeded(incomingBytes: lineData.count)
            try append(lineData)
        } catch {
            // Intentionally swallow sink write errors.
        }
    }

    /// Loads events from the active file and optional archived file.
    public func loadEvents(
        limit: Int? = nil,
        includeArchived: Bool = true
    ) -> [MHLogEvent] {
        let urls = candidateURLs(includeArchived: includeArchived)
        var values = [MHLogEvent]()

        for url in urls {
            values.append(contentsOf: decodeEvents(at: url))
        }

        if let limit,
           limit > 0,
           values.count > limit {
            return Array(values.suffix(limit))
        }

        return values
    }

    public func readJSONLines(includeArchived: Bool = true) -> String {
        let urls = candidateURLs(includeArchived: includeArchived)
        var values = [String]()

        for url in urls {
            guard let data = try? Data(contentsOf: url),
                  let stringValue = String(data: data, encoding: .utf8),
                  stringValue.isEmpty == false else {
                continue
            }

            values.append(stringValue)
        }

        return values.joined(separator: "\n")
    }

    public func clear() {
        if fileManager.fileExists(atPath: fileURL.path) {
            try? fileManager.removeItem(at: fileURL)
        }
        if fileManager.fileExists(atPath: archivedFileURL.path) {
            try? fileManager.removeItem(at: archivedFileURL)
        }
    }
}

private extension MHJSONLLogSink {
    func candidateURLs(includeArchived: Bool) -> [URL] {
        if includeArchived {
            return [archivedFileURL, fileURL]
        }
        return [fileURL]
    }

    func ensureParentDirectoryExists() throws {
        let directoryURL = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
    }

    func encodedLineData(for event: MHLogEvent) throws -> Data {
        var data = try encoder.encode(event)
        data.append(contentsOf: "\n".utf8)
        return data
    }

    func rotateIfNeeded(incomingBytes: Int) throws {
        let currentSize = fileSize(at: fileURL)
        guard currentSize + incomingBytes > maximumFileSizeBytes else {
            return
        }

        guard fileManager.fileExists(atPath: fileURL.path) else {
            return
        }

        if fileManager.fileExists(atPath: archivedFileURL.path) {
            try fileManager.removeItem(at: archivedFileURL)
        }

        try fileManager.moveItem(
            at: fileURL,
            to: archivedFileURL
        )
    }

    func append(_ data: Data) throws {
        if fileManager.fileExists(atPath: fileURL.path) == false {
            fileManager.createFile(atPath: fileURL.path, contents: .init())
        }

        let handle = try FileHandle(forWritingTo: fileURL)
        defer {
            try? handle.close()
        }
        try handle.seekToEnd()
        try handle.write(contentsOf: data)
    }

    func fileSize(at url: URL) -> Int {
        guard let attributes = try? fileManager.attributesOfItem(atPath: url.path) else {
            return 0
        }
        if let fileSize = attributes[.size] as? Int {
            return fileSize
        }
        if let fileSize = attributes[.size] as? Int64 {
            return Int(fileSize)
        }
        if let fileSize = attributes[.size] as? UInt64 {
            return Int(fileSize)
        }
        return 0
    }

    func decodeEvents(at url: URL) -> [MHLogEvent] {
        guard let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8) else {
            return []
        }

        return text.split(whereSeparator: \.isNewline).compactMap { line in
            let lineData = Data(line.utf8)
            return try? decoder.decode(MHLogEvent.self, from: lineData)
        }
    }
}
