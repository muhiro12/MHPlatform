import Foundation

final class MHRouteExecutionReadinessFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var readiness: Bool

    var value: Bool {
        lock.lock()
        let result = readiness
        lock.unlock()
        return result
    }

    init(initialValue: Bool) {
        readiness = initialValue
    }

    func set(_ isReady: Bool) {
        lock.lock()
        readiness = isReady
        lock.unlock()
    }
}
