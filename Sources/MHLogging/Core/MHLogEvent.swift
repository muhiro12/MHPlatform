import Foundation

/// Structured log event model that can be stored and exported as JSON Lines.
public struct MHLogEvent: Codable, Equatable, Sendable {
    public let timestamp: Date
    public let level: MHLogLevel
    public let subsystem: String
    public let category: String
    public let message: String
    public let metadata: [String: String]
    public let source: MHLogSource

    public init(
        level: MHLogLevel,
        subsystem: String,
        category: String,
        message: String,
        source: MHLogSource,
        timestamp: Date = .init(),
        metadata: [String: String] = [:]
    ) {
        self.timestamp = timestamp
        self.level = level
        self.subsystem = subsystem
        self.category = category
        self.message = message
        self.metadata = metadata
        self.source = source
    }
}

public extension MHLogEvent {
    /// Single-line text useful for previews and debug UIs.
    var summaryLine: String {
        var values = [
            timestamp.ISO8601Format(),
            "[\(level.name.uppercased())]",
            "\(subsystem)/\(category)",
            message
        ]
        if metadata.isEmpty == false {
            values.append(metadataLine)
        }
        values.append("@\(source.file):\(source.line)")
        return values.joined(separator: " ")
    }

    /// Canonical metadata text sorted by key for deterministic output.
    var metadataLine: String {
        let sortedKeys = metadata.keys.sorted()
        var pairs = [String]()

        for key in sortedKeys {
            let value = metadata[key] ?? .init()
            pairs.append("\(key)=\(value)")
        }

        return pairs.joined(separator: " ")
    }
}
