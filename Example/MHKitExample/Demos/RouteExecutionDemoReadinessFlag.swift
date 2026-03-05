import Foundation

final class RouteExecutionDemoReadinessFlag: @unchecked Sendable {
    nonisolated private let lock = NSLock()
    nonisolated(unsafe) private var readiness: Bool

    nonisolated var value: Bool {
        lock.lock()
        let result = readiness
        lock.unlock()
        return result
    }

    nonisolated init(initialValue: Bool) {
        readiness = initialValue
    }

    nonisolated func set(_ isReady: Bool) {
        lock.lock()
        readiness = isReady
        lock.unlock()
    }
}
