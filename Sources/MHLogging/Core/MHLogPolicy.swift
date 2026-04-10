import Foundation

/// Logging retention policy.
public struct MHLogPolicy: Equatable, Sendable {
    private enum Limits {
        static let minimumCapacity = 1
        static let debugInMemoryEvents = 2_000
        static let releaseInMemoryEvents = 200
    }

    /// Default policy for debug builds.
    public static let debugDefault = Self(
        minimumLevel: .debug,
        maximumInMemoryEvents: Limits.debugInMemoryEvents
    )

    /// Default policy for release builds.
    public static let releaseDefault = Self(
        minimumLevel: .warning,
        maximumInMemoryEvents: Limits.releaseInMemoryEvents
    )

    /// Build-configuration default policy.
    public static var `default`: Self {
        #if DEBUG
        return .debugDefault
        #else
        return .releaseDefault
        #endif
    }

    public let minimumLevel: MHLogLevel
    public let maximumInMemoryEvents: Int

    public init(
        minimumLevel: MHLogLevel,
        maximumInMemoryEvents: Int
    ) {
        self.minimumLevel = minimumLevel
        self.maximumInMemoryEvents = max(
            maximumInMemoryEvents,
            Limits.minimumCapacity
        )
    }
}
