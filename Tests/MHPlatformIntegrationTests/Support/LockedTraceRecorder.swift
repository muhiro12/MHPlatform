import Foundation

final class LockedTraceRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storedValues = [String]()

    func record(_ value: String) {
        lock.lock()
        defer {
            lock.unlock()
        }

        storedValues.append(value)
    }

    func values() -> [String] {
        lock.lock()
        defer {
            lock.unlock()
        }

        return storedValues
    }
}
