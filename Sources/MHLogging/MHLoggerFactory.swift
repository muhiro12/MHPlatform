import Foundation

/// Shared factory for app-side logger bootstrapping.
public struct MHLoggerFactory: Sendable {
    /// Default app-side factory that emits to OSLog using the build-config policy.
    public static var osLogDefault: Self {
        .init(
            policy: .default,
            sinks: [MHOSLogSink()]
        )
    }

    let store: MHLogStore
    let policy: MHLogPolicy
    let subsystem: String?

    /// Creates a logger factory backed by a shared log store.
    public init(
        policy: MHLogPolicy = .default,
        sinks: [any MHLogSink] = [],
        subsystem: String? = nil
    ) {
        self.store = .init(
            policy: policy,
            sinks: sinks
        )
        self.policy = policy
        self.subsystem = subsystem
    }

    /// Creates a logger that shares the factory's store and policy.
    public func logger(
        category: String,
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
