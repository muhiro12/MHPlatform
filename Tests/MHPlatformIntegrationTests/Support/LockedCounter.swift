import Foundation

final class LockedCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0

    func increment() -> Int {
        lock.lock()
        value += 1
        let currentValue = value
        lock.unlock()
        return currentValue
    }
}
