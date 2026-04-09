import Foundation
import Observation

/// App-owned logging bootstrap that shares runtime mode, store, and persistence.
@preconcurrency
@MainActor
@Observable
public final class MHLoggingBootstrap {
    private static let defaultPolicy = MHLogPolicy(
        minimumLevel: .warning,
        persistsToDisk: true,
        maximumInMemoryEvents: MHLogPolicy.debugDefault.maximumInMemoryEvents,
        maximumDiskBytes: MHLogPolicy.debugDefault.maximumDiskBytes
    )

    /// Controls whether the bootstrap captures detailed debug events.
    public var isDebugMode: Bool {
        didSet {
            runtimeState.isDebugMode = isDebugMode
        }
    }

    /// Shared in-memory store used by debug UI and queries.
    public let store: MHLogStore

    private let policy: MHLogPolicy
    private let loggerFactory: MHLoggerFactory
    private let runtimeState: MHLogRuntimeState
    private let jsonSink: MHJSONLLogSink?

    @ObservationIgnored private let restoreTask: Task<Void, Never>

    /// Creates a logging bootstrap with optional automatic JSONL persistence.
    public init(
        isDebugMode: Bool = false,
        policy: MHLogPolicy? = nil,
        subsystem: String? = nil,
        fileURL: URL? = nil,
        fileManager: FileManager = .default,
        additionalSinks: [any MHLogSink] = []
    ) {
        let resolvedPolicy = policy ?? Self.defaultPolicy

        self.policy = resolvedPolicy
        self.runtimeState = .init(isDebugMode: isDebugMode)
        self.isDebugMode = isDebugMode

        if resolvedPolicy.persistsToDisk {
            let resolvedFileURL = fileURL ?? Self.defaultFileURL(
                fileManager: fileManager
            )
            self.jsonSink = MHJSONLLogSink(
                fileURL: resolvedFileURL,
                maximumFileSizeBytes: resolvedPolicy.maximumDiskBytes
            )
        } else {
            self.jsonSink = nil
        }

        var sinks: [any MHLogSink] = [MHOSLogSink()]
        if let jsonSink = self.jsonSink {
            sinks.append(jsonSink)
        }
        sinks.append(contentsOf: additionalSinks)

        self.store = MHLogStore(
            policy: resolvedPolicy,
            runtimeState: self.runtimeState,
            sinks: sinks
        )
        self.loggerFactory = MHLoggerFactory(
            store: self.store,
            policy: resolvedPolicy,
            subsystem: subsystem,
            runtimeState: self.runtimeState
        )

        if let jsonSink = self.jsonSink {
            restoreTask = Task { [store = self.store, jsonSink] in
                let events = await jsonSink.loadEvents()
                await store.seed(events)
            }
        } else {
            restoreTask = Task { /* No persisted logs to restore. */ }
        }
    }

    /// Returns a logger bound to the shared runtime state and store.
    public func logger(
        category: String? = nil,
        source: String = #fileID
    ) -> MHLogger {
        loggerFactory.logger(
            category: category,
            source: source
        )
    }

    /// Waits until any persisted log events have been loaded into memory.
    public func waitForInitialLoad() async {
        await restoreTask.value
    }

    /// Reads the persisted JSONL payload for the current bootstrap, if any.
    public func persistedJSONLines(includeArchived: Bool = true) async -> String {
        await waitForInitialLoad()

        guard let jsonSink else {
            return ""
        }

        return await jsonSink.readJSONLines(includeArchived: includeArchived)
    }

    /// Clears the in-memory store and any persisted JSONL file.
    public func clear() async {
        await waitForInitialLoad()
        await self.store.clear()

        if let jsonSink = self.jsonSink {
            await jsonSink.clear()
        }
    }
}

private extension MHLoggingBootstrap {
    static func defaultFileURL(fileManager: FileManager) -> URL {
        let baseDirectory = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? fileManager.temporaryDirectory

        let bundleIdentifier = Bundle.main.bundleIdentifier?.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let directoryName = bundleIdentifier?.isEmpty == false
            ? bundleIdentifier ?? "MHPlatform"
            : "MHPlatform"

        return baseDirectory
            .appendingPathComponent(directoryName)
            .appendingPathComponent("MHLogging")
            .appendingPathComponent("logs.jsonl")
    }
}
