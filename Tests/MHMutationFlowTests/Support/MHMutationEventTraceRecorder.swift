import Foundation
import MHMutationFlow

final class MHMutationEventTraceRecorder<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private let traceBuilder: @Sendable (MHMutationEvent<Value>) -> String
    private var traces = [String]()

    init(
        traceBuilder: @escaping @Sendable (MHMutationEvent<Value>) -> String
    ) {
        self.traceBuilder = traceBuilder
    }

    func record(_ event: MHMutationEvent<Value>) {
        lock.lock()
        traces.append(traceBuilder(event))
        lock.unlock()
    }

    func all() -> [String] {
        lock.lock()
        defer {
            lock.unlock()
        }

        return traces
    }
}
