/// A single destructive reset operation.
@preconcurrency
public struct MHDestructiveResetStep: Sendable {
    /// Stable step name used for logs and outcomes.
    public let name: String

    /// Async action to execute.
    public let action: @Sendable () async throws -> Void

    /// Creates a reset step.
    @preconcurrency
    public init(
        name: String,
        action: @escaping @Sendable () async throws -> Void
    ) {
        self.name = name
        self.action = action
    }
}
