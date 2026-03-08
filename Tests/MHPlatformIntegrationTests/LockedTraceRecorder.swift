import Foundation

final class LockedTraceRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storedValues = [String]()

    func record(_ value: String) {
        lock.lock()
        storedValues.append(value)
        lock.unlock()
    }

    func values() -> [String] {
        lock.lock()
        let currentValues = storedValues
        lock.unlock()
        return currentValues
    }
}
