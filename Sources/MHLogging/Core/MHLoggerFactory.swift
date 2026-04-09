/// Lightweight factory for app-owned logging setup.
public struct MHLoggerFactory: Sendable {
    /// Default app-side factory that emits to OSLog using the build-config policy.
    public static var osLogDefault: Self {
        .init(
            policy: .default,
            sinks: [MHOSLogSink()]
        )
    }

    public let store: MHLogStore
    public let policy: MHLogPolicy
    public let subsystem: String?
    public let runtimeState: MHLogRuntimeState?

    /// Creates a factory around an existing log store.
    public init(
        store: MHLogStore,
        policy: MHLogPolicy = .default,
        subsystem: String? = nil,
        runtimeState: MHLogRuntimeState? = nil
    ) {
        self.store = store
        self.policy = policy
        self.subsystem = subsystem
        self.runtimeState = runtimeState
    }

    /// Creates a factory that owns its log store configuration.
    public init(
        policy: MHLogPolicy = .default,
        subsystem: String? = nil,
        sinks: [any MHLogSink] = [],
        runtimeState: MHLogRuntimeState? = nil
    ) {
        self.init(
            store: .init(
                policy: policy,
                runtimeState: runtimeState,
                sinks: sinks
            ),
            policy: policy,
            subsystem: subsystem,
            runtimeState: runtimeState
        )
    }

    /// Creates a logger for the given category and source file identifier.
    public func logger(
        category: String? = nil,
        source: String = #fileID
    ) -> MHLogger {
        .init(
            source,
            store: store,
            subsystem: subsystem,
            category: category,
            policy: policy,
            runtimeState: runtimeState
        )
    }
}
