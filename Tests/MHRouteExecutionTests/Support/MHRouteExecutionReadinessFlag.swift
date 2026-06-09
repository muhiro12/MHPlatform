import Foundation

final class MHRouteExecutionReadinessFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var readiness: Bool

    var value: Bool {
        lock.lock()
        defer {
            lock.unlock()
        }

        return readiness
    }

    init(initialValue: Bool) {
        readiness = initialValue
    }

    func set(_ isReady: Bool) {
        lock.lock()
        defer {
            lock.unlock()
        }

        readiness = isReady
    }
}
