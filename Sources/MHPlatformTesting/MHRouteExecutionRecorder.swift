/// Ordered recorder for route-execution test assertions.
public actor MHRouteExecutionRecorder<Value: Sendable> {
    private var recordedValues = [Value]()

    /// Creates an empty recorder.
    public init() {
        // Intentionally empty.
    }

    /// Appends a value to the ordered trace.
    public func record(_ value: Value) {
        recordedValues.append(value)
    }

    /// Returns the recorded values in insertion order.
    public func values() -> [Value] {
        recordedValues
    }
}
