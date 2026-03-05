import MHRouteExecution
import Testing

extension MHRouteExecutionTests {
    func expectQueued(_ resolution: MHRouteResolution<Int>) {
        switch resolution {
        case .queued:
            break
        case .applied(let outcome):
            Issue.record("Expected queued resolution, got applied(\(outcome)).")
        }
    }

    func expectApplied(
        _ resolution: MHRouteResolution<Int>,
        expected: Int
    ) {
        switch resolution {
        case .queued:
            Issue.record("Expected applied resolution, got queued.")
        case .applied(let outcome):
            #expect(outcome == expected)
        }
    }
}
