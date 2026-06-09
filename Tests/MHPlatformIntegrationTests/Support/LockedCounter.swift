import Foundation

final class LockedCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0

    func increment() -> Int {
        lock.lock()
        defer {
            lock.unlock()
        }

        value += 1
        return value
    }
}
