import Foundation
import MHPreferences
import Observation

/// App-owned logging bootstrap that shares runtime capture settings, live store, and optional last-session snapshots.
@preconcurrency
@MainActor
@Observable
public final class MHLoggingBootstrap {
    private static let defaultPolicy = MHLogPolicy(
        minimumLevel: .warning,
        maximumInMemoryEvents: MHLogPolicy.debugDefault.maximumInMemoryEvents
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

    /// Returns whether a previous session snapshot is currently available.
    public private(set) var hasPreviousSession: Bool

    private let loggerFactory: MHLoggerFactory
    private let runtimeState: MHLogRuntimeState

    @ObservationIgnored private let snapshotSink: MHLogSessionSnapshotSink?
    @ObservationIgnored private var previousSessionEvents: [MHLogEvent]

    /// Creates a logging bootstrap with optional last-session snapshot storage.
    public convenience init(
        captureLevel: MHLogLevel? = nil,
        policy: MHLogPolicy? = nil,
        subsystem: String? = nil,
        snapshotStorageKeys: MHLogSnapshotStorageKeys? = nil,
        snapshotStore: MHPreferenceStore = .init(),
        additionalSinks: [any MHLogSink] = []
    ) {
        self.init(
            captureLevel: captureLevel,
            policy: policy,
            subsystem: subsystem,
            snapshotStorageKeys: snapshotStorageKeys,
            snapshotStore: snapshotStore,
            additionalSinks: additionalSinks,
            sessionIdentifier: MHLogSessionSnapshotSink.processSessionIdentifier
        )
    }

    init(
        captureLevel: MHLogLevel?,
        policy: MHLogPolicy?,
        subsystem: String?,
        snapshotStorageKeys: MHLogSnapshotStorageKeys?,
        snapshotStore: MHPreferenceStore,
        additionalSinks: [any MHLogSink],
        sessionIdentifier: UUID
    ) {
        let resolvedPolicy = policy ?? Self.defaultPolicy
        let resolvedCaptureLevel = Self.resolveCaptureLevel(
            captureLevel,
            policy: resolvedPolicy
        )
        let runtimeState = Self.makeRuntimeState(
            captureLevel: resolvedCaptureLevel,
            policy: resolvedPolicy
        )
        let snapshotSeed = Self.makeSnapshotSeed(
            snapshotStorageKeys: snapshotStorageKeys,
            snapshotStore: snapshotStore,
            sessionIdentifier: sessionIdentifier
        )
        let snapshotSink = Self.makeSnapshotSink(
            snapshotSeed: snapshotSeed,
            snapshotStore: snapshotStore,
            sessionIdentifier: sessionIdentifier
        )
        let sinks = Self.makeSinks(
            snapshotSink: snapshotSink,
            additionalSinks: additionalSinks
        )
        let store = MHLogStore(
            policy: resolvedPolicy,
            runtimeState: runtimeState,
            sinks: sinks,
            initialEvents: snapshotSeed?.currentEvents ?? []
        )

        self.runtimeState = runtimeState
        self.captureLevel = resolvedCaptureLevel
        self.previousSessionEvents = snapshotSeed?.previousEvents ?? []
        self.hasPreviousSession = previousSessionEvents.isEmpty == false
        self.snapshotSink = snapshotSink
        self.store = store
        self.loggerFactory = MHLoggerFactory(
            store: store,
            policy: resolvedPolicy,
            subsystem: subsystem,
            runtimeState: runtimeState
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

    /// Returns events for the selected session scope filtered by `query`.
    public func events(
        in scope: MHLogSessionScope,
        matching query: MHLogQuery = .init()
    ) async -> [MHLogEvent] {
        switch scope {
        case .current:
            return await store.events(matching: query)
        case .previous:
            return MHLogEventCollection.filteredEvents(
                in: previousSessionEvents,
                matching: query
            )
        }
    }

    /// Exports the selected session scope as JSON Lines text.
    public func exportJSONLines(
        in scope: MHLogSessionScope,
        matching query: MHLogQuery = .init()
    ) async -> String {
        switch scope {
        case .current:
            return await store.exportJSONLines(matching: query)
        case .previous:
            return MHLogEventCollection.exportJSONLines(
                from: previousSessionEvents,
                matching: query
            )
        }
    }

    /// Clears the in-memory store and any configured last-session snapshots.
    public func clear() async {
        await store.clear()
        previousSessionEvents.removeAll(keepingCapacity: true)
        hasPreviousSession = false

        if let snapshotSink {
            await snapshotSink.clear()
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

    static func makeSnapshotSeed(
        snapshotStorageKeys: MHLogSnapshotStorageKeys?,
        snapshotStore: MHPreferenceStore,
        sessionIdentifier: UUID
    ) -> MHLogSessionSnapshotSink.Seed? {
        guard let snapshotStorageKeys else {
            return nil
        }

        return MHLogSessionSnapshotSink.makeSeed(
            snapshotStorageKeys: snapshotStorageKeys,
            snapshotStore: snapshotStore,
            sessionIdentifier: sessionIdentifier
        )
    }

    static func makeSnapshotSink(
        snapshotSeed: MHLogSessionSnapshotSink.Seed?,
        snapshotStore: MHPreferenceStore,
        sessionIdentifier: UUID
    ) -> MHLogSessionSnapshotSink? {
        guard let snapshotSeed else {
            return nil
        }

        return MHLogSessionSnapshotSink(
            seed: snapshotSeed,
            snapshotStore: snapshotStore,
            sessionIdentifier: sessionIdentifier
        )
    }

    static func makeSinks(
        snapshotSink: MHLogSessionSnapshotSink?,
        additionalSinks: [any MHLogSink]
    ) -> [any MHLogSink] {
        var sinks: [any MHLogSink] = [MHOSLogSink()]
        if let snapshotSink {
            sinks.append(snapshotSink)
        }
        sinks.append(contentsOf: additionalSinks)
        return sinks
    }
}
