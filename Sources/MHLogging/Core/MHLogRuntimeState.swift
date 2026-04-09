import Foundation

/// Thread-safe runtime logging mode shared by loggers and stores.
public final class MHLogRuntimeState: @unchecked Sendable {
    private let lock = NSLock()

    private var _isDebugMode: Bool

    /// Minimum level to capture while debug mode is disabled.
    public let standardMinimumLevel: MHLogLevel

    /// Minimum level to capture while debug mode is enabled.
    public let debugMinimumLevel: MHLogLevel

    /// Indicates whether detailed debug logging is enabled.
    public var isDebugMode: Bool {
        get {
            lock.withLock {
                _isDebugMode
            }
        }
        set {
            lock.withLock {
                _isDebugMode = newValue
            }
        }
    }

    /// Returns the currently active minimum capture level.
    public var captureMinimumLevel: MHLogLevel {
        isDebugMode ? debugMinimumLevel : standardMinimumLevel
    }

    /// Creates a runtime logging state with the supplied defaults.
    public init(
        isDebugMode: Bool = false,
        standardMinimumLevel: MHLogLevel = .warning,
        debugMinimumLevel: MHLogLevel = .debug
    ) {
        self._isDebugMode = isDebugMode
        self.standardMinimumLevel = standardMinimumLevel
        self.debugMinimumLevel = debugMinimumLevel
    }

    /// Returns whether `level` should be captured in the current runtime mode.
    public func shouldCapture(_ level: MHLogLevel) -> Bool {
        level >= captureMinimumLevel
    }
}

private extension NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        lock()
        defer { unlock() }
        return body()
    }
}
