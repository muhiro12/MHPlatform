/// A named unit of mutation work.
@preconcurrency
public struct MHMutation<Value: Sendable>: Sendable {
    /// Stable mutation name for logs and event streams.
    public let name: String

    /// Async mutation operation.
    public let operation: @Sendable () async throws -> Value

    /// Creates a mutation unit.
    @preconcurrency
    public init(
        name: String,
        operation: @escaping @Sendable () async throws -> Value
    ) {
        self.name = name
        self.operation = operation
    }
}
