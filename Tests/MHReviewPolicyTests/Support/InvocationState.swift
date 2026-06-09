import Foundation

final class InvocationState: @unchecked Sendable {
    private let lock = NSLock()
    private var randomCallCount = 0
    private var sleepCallCount = 0
    private var events = [String]()

    func recordRandomCall() {
        lock.lock()
        defer {
            lock.unlock()
        }

        randomCallCount += 1
    }

    func recordSleepCall() {
        lock.lock()
        defer {
            lock.unlock()
        }

        sleepCallCount += 1
    }

    func recordEvent(_ event: String) {
        lock.lock()
        defer {
            lock.unlock()
        }

        events.append(event)
    }

    func randomCallCountValue() -> Int {
        lock.lock()
        defer {
            lock.unlock()
        }

        return randomCallCount
    }

    func sleepCallCountValue() -> Int {
        lock.lock()
        defer {
            lock.unlock()
        }

        return sleepCallCount
    }

    func eventsValue() -> [String] {
        lock.lock()
        defer {
            lock.unlock()
        }

        return events
    }
}
