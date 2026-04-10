import Foundation

/// Thread-safe runtime logging mode shared by loggers and stores.
public final class MHLogRuntimeState: @unchecked Sendable {
    private let lock = NSLock()

    private var _captureMinimumLevel: MHLogLevel

    /// Minimum level to capture while debug mode is disabled.
    public let standardMinimumLevel: MHLogLevel

    /// Minimum level to capture while debug mode is enabled.
    public let debugMinimumLevel: MHLogLevel

    /// Returns the currently active minimum capture level.
    public var captureMinimumLevel: MHLogLevel {
        get {
            lock.withLock {
                _captureMinimumLevel
            }
        }
        set {
            lock.withLock {
                _captureMinimumLevel = newValue
            }
        }
    }

    /// Creates a runtime logging state with the supplied defaults.
    public init(
        captureMinimumLevel: MHLogLevel? = nil,
        standardMinimumLevel: MHLogLevel = .warning,
        debugMinimumLevel: MHLogLevel = .debug
    ) {
        self.standardMinimumLevel = standardMinimumLevel
        self.debugMinimumLevel = debugMinimumLevel
        self._captureMinimumLevel = captureMinimumLevel
            ?? standardMinimumLevel
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
