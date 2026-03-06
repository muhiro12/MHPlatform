import Foundation

/// Lightweight logger facade that emits `MHLogEvent` values to `MHLogStore`.
public struct MHLogger: Sendable {
    public let subsystem: String
    public let category: String

    private let store: MHLogStore
    private let policy: MHLogPolicy

    public init(
        _ fileID: String,
        store: MHLogStore,
        subsystem: String? = nil,
        category: String? = nil,
        policy: MHLogPolicy = .default
    ) {
        self.subsystem = Self.resolveSubsystem(subsystem)
        self.category = category ?? fileID
        self.store = store
        self.policy = policy
    }

    public func debug(
        _ message: @autoclosure () -> String,
        metadata: [String: String] = [:],
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        log(
            .debug,
            message(),
            metadata: metadata,
            file: file,
            function: function,
            line: line
        )
    }

    public func info(
        _ message: @autoclosure () -> String,
        metadata: [String: String] = [:],
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        log(
            .info,
            message(),
            metadata: metadata,
            file: file,
            function: function,
            line: line
        )
    }

    public func notice(
        _ message: @autoclosure () -> String,
        metadata: [String: String] = [:],
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        log(
            .notice,
            message(),
            metadata: metadata,
            file: file,
            function: function,
            line: line
        )
    }

    public func warning(
        _ message: @autoclosure () -> String,
        metadata: [String: String] = [:],
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        log(
            .warning,
            message(),
            metadata: metadata,
            file: file,
            function: function,
            line: line
        )
    }

    public func error(
        _ message: @autoclosure () -> String,
        metadata: [String: String] = [:],
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        log(
            .error,
            message(),
            metadata: metadata,
            file: file,
            function: function,
            line: line
        )
    }

    public func critical(
        _ message: @autoclosure () -> String,
        metadata: [String: String] = [:],
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        log(
            .critical,
            message(),
            metadata: metadata,
            file: file,
            function: function,
            line: line
        )
    }

    public func log(
        _ level: MHLogLevel,
        _ message: @autoclosure () -> String,
        metadata: [String: String] = [:],
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        guard level >= policy.minimumLevel else {
            return
        }

        let source = MHLogSource(
            file: file,
            function: function,
            line: line
        )
        let event = makeEvent(
            level: level,
            message: message(),
            metadata: metadata,
            source: source
        )

        Task {
            await store.record(event)
        }
    }

    public func logImmediately(
        _ level: MHLogLevel,
        _ message: String,
        metadata: [String: String] = [:],
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) async {
        guard level >= policy.minimumLevel else {
            return
        }

        let source = MHLogSource(
            file: file,
            function: function,
            line: line
        )
        let event = makeEvent(
            level: level,
            message: message,
            metadata: metadata,
            source: source
        )
        await store.record(event)
    }
}

private extension MHLogger {
    static func resolveSubsystem(_ subsystem: String?) -> String {
        if let subsystem {
            let normalizedSubsystem = subsystem.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            if normalizedSubsystem.isEmpty == false {
                return normalizedSubsystem
            }
        }

        if let bundleIdentifier = Bundle.main.bundleIdentifier,
           bundleIdentifier.isEmpty == false {
            return bundleIdentifier
        }

        return "MHPlatform"
    }

    func makeEvent(
        level: MHLogLevel,
        message: String,
        metadata: [String: String],
        source: MHLogSource
    ) -> MHLogEvent {
        .init(
            level: level,
            subsystem: subsystem,
            category: category,
            message: message,
            source: source,
            metadata: metadata
        )
    }
}
