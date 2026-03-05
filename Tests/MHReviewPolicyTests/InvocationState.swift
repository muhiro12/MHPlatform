import Foundation

final class InvocationState: @unchecked Sendable {
    private let lock = NSLock()
    private var randomCallCount = 0
    private var sleepCallCount = 0
    private var events = [String]()

    func recordRandomCall() {
        lock.lock()
        randomCallCount += 1
        lock.unlock()
    }

    func recordSleepCall() {
        lock.lock()
        sleepCallCount += 1
        lock.unlock()
    }

    func recordEvent(_ event: String) {
        lock.lock()
        events.append(event)
        lock.unlock()
    }

    func randomCallCountValue() -> Int {
        lock.lock()
        let snapshot = randomCallCount
        lock.unlock()
        return snapshot
    }

    func sleepCallCountValue() -> Int {
        lock.lock()
        let snapshot = sleepCallCount
        lock.unlock()
        return snapshot
    }

    func eventsValue() -> [String] {
        lock.lock()
        let snapshot = events
        lock.unlock()
        return snapshot
    }
}
