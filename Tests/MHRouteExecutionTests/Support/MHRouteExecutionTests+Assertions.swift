import MHRouteExecution
import Testing

extension MHRouteExecutionTests {
    func expectQueued(_ outcome: MHRouteExecutionOutcome<Int>) {
        switch outcome {
        case .queued:
            break
        case .applied(let resolvedValue):
            Issue.record("Expected queued outcome, got applied(\(resolvedValue)).")
        case .deduplicated:
            Issue.record("Expected queued outcome, got deduplicated.")
        }
    }

    func expectApplied(
        _ outcome: MHRouteExecutionOutcome<Int>,
        expected: Int
    ) {
        switch outcome {
        case .queued:
            Issue.record("Expected applied outcome, got queued.")
        case .applied(let resolvedValue):
            #expect(resolvedValue == expected)
        case .deduplicated:
            Issue.record("Expected applied outcome, got deduplicated.")
        }
    }

    func expectDeduplicated(_ outcome: MHRouteExecutionOutcome<Int>) {
        switch outcome {
        case .deduplicated:
            break
        case .queued:
            Issue.record("Expected deduplicated outcome, got queued.")
        case .applied(let resolvedValue):
            Issue.record("Expected deduplicated outcome, got applied(\(resolvedValue)).")
        }
    }
}
