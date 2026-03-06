/// Lightweight factory for app-owned logging setup.
public struct MHLoggerFactory: Sendable {
    public let store: MHLogStore
    public let policy: MHLogPolicy
    public let subsystem: String?

    /// Creates a factory around an existing log store.
    public init(
        store: MHLogStore,
        policy: MHLogPolicy = .default,
        subsystem: String? = nil
    ) {
        self.store = store
        self.policy = policy
        self.subsystem = subsystem
    }

    /// Creates a factory that owns its log store configuration.
    public init(
        policy: MHLogPolicy = .default,
        subsystem: String? = nil,
        sinks: [any MHLogSink] = []
    ) {
        self.init(
            store: .init(
                policy: policy,
                sinks: sinks
            ),
            policy: policy,
            subsystem: subsystem
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
            policy: policy
        )
    }
}
