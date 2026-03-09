/// Live mutation run handle exposing event stream and terminal outcome.
public struct MHMutationRun<Value: Sendable>: Sendable {
    /// Ordered mutation event stream.
    public let events: AsyncStream<MHMutationEvent<Value>>

    /// Terminal outcome task.
    public let outcome: Task<MHMutationOutcome<Value>, Never>

    /// Creates a mutation run handle.
    public init(
        events: AsyncStream<MHMutationEvent<Value>>,
        outcome: Task<MHMutationOutcome<Value>, Never>
    ) {
        self.events = events
        self.outcome = outcome
    }
}
