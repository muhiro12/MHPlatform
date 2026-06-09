import Foundation

/// Thread-safe cancellation signal shared across mutation execution steps.
public final class MHCancellationHandle: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false

    /// Returns `true` when cancellation was requested.
    public var isCancelled: Bool {
        lock.lock()
        defer {
            lock.unlock()
        }

        return cancelled
    }

    /// Creates an active cancellation handle.
    public init() {
        // Intentionally empty.
    }

    /// Marks this handle as cancelled.
    public func cancel() {
        lock.lock()
        defer {
            lock.unlock()
        }

        cancelled = true
    }
}
