import Foundation

/// Logging retention and persistence policy.
public struct MHLogPolicy: Equatable, Sendable {
    private enum Limits {
        static let minimumCapacity = 1
        static let debugInMemoryEvents = 2_000
        static let debugDiskBytes = 4_000_000
        static let releaseInMemoryEvents = 200
        static let releaseDiskBytes = 400_000
    }

    /// Default policy for debug builds.
    public static let debugDefault = Self(
        minimumLevel: .debug,
        persistsToDisk: true,
        maximumInMemoryEvents: Limits.debugInMemoryEvents,
        maximumDiskBytes: Limits.debugDiskBytes
    )

    /// Default policy for release builds.
    public static let releaseDefault = Self(
        minimumLevel: .warning,
        persistsToDisk: false,
        maximumInMemoryEvents: Limits.releaseInMemoryEvents,
        maximumDiskBytes: Limits.releaseDiskBytes
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
    public let persistsToDisk: Bool
    public let maximumInMemoryEvents: Int
    public let maximumDiskBytes: Int

    public init(
        minimumLevel: MHLogLevel,
        persistsToDisk: Bool,
        maximumInMemoryEvents: Int,
        maximumDiskBytes: Int
    ) {
        self.minimumLevel = minimumLevel
        self.persistsToDisk = persistsToDisk
        self.maximumInMemoryEvents = max(
            maximumInMemoryEvents,
            Limits.minimumCapacity
        )
        self.maximumDiskBytes = max(
            maximumDiskBytes,
            Limits.minimumCapacity
        )
    }
}
