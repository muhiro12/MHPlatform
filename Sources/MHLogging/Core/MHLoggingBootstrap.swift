import Foundation
import Observation

/// App-owned logging bootstrap that shares runtime capture settings, store, and persistence.
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

    /// Current minimum level captured by the shared logging runtime.
    public var captureLevel: MHLogLevel {
        didSet {
            guard captureLevel != oldValue else {
                return
            }

            runtimeState.captureMinimumLevel = captureLevel
        }
    }

    /// Shared in-memory store used by debug UI and queries.
    public let store: MHLogStore

    private let loggerFactory: MHLoggerFactory
    private let runtimeState: MHLogRuntimeState
    private let jsonSink: MHJSONLLogSink?

    @ObservationIgnored private let restoreTask: Task<Void, Never>

    /// Creates a logging bootstrap with optional automatic JSONL persistence.
    public init(
        captureLevel: MHLogLevel? = nil,
        policy: MHLogPolicy? = nil,
        subsystem: String? = nil,
        fileURL: URL? = nil,
        fileManager: FileManager = .default,
        additionalSinks: [any MHLogSink] = []
    ) {
        let resolvedPolicy = policy ?? Self.defaultPolicy
        let resolvedCaptureLevel = Self.resolveCaptureLevel(
            captureLevel,
            policy: resolvedPolicy
        )

        self.runtimeState = Self.makeRuntimeState(
            captureLevel: resolvedCaptureLevel,
            policy: resolvedPolicy
        )
        self.captureLevel = resolvedCaptureLevel

        self.jsonSink = Self.makeJSONLLogSink(
            policy: resolvedPolicy,
            fileURL: fileURL,
            fileManager: fileManager
        )

        let sinks = Self.makeSinks(
            jsonSink: self.jsonSink,
            additionalSinks: additionalSinks
        )

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

        restoreTask = Self.makeRestoreTask(
            store: self.store,
            jsonSink: self.jsonSink
        )
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
    static func resolveCaptureLevel(
        _ captureLevel: MHLogLevel?,
        policy: MHLogPolicy
    ) -> MHLogLevel {
        captureLevel
            ?? policy.minimumLevel
    }

    static func makeRuntimeState(
        captureLevel: MHLogLevel,
        policy: MHLogPolicy
    ) -> MHLogRuntimeState {
        .init(
            captureMinimumLevel: captureLevel,
            standardMinimumLevel: policy.minimumLevel,
            debugMinimumLevel: .debug
        )
    }

    static func makeJSONLLogSink(
        policy: MHLogPolicy,
        fileURL: URL?,
        fileManager: FileManager
    ) -> MHJSONLLogSink? {
        guard policy.persistsToDisk else {
            return nil
        }

        let resolvedFileURL = fileURL ?? defaultFileURL(fileManager: fileManager)
        return MHJSONLLogSink(
            fileURL: resolvedFileURL,
            maximumFileSizeBytes: policy.maximumDiskBytes
        )
    }

    static func makeSinks(
        jsonSink: MHJSONLLogSink?,
        additionalSinks: [any MHLogSink]
    ) -> [any MHLogSink] {
        var sinks: [any MHLogSink] = [MHOSLogSink()]
        if let jsonSink {
            sinks.append(jsonSink)
        }
        sinks.append(contentsOf: additionalSinks)
        return sinks
    }

    static func makeRestoreTask(
        store: MHLogStore,
        jsonSink: MHJSONLLogSink?
    ) -> Task<Void, Never> {
        if let jsonSink {
            return Task {
                let events = await jsonSink.loadEvents()
                await store.seed(events)
            }
        }

        return Task { /* No persisted logs to restore. */ }
    }

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
