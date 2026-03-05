/// Side-effect step executed after a successful mutation.
@preconcurrency
public struct MHMutationStep: Sendable {
    /// Step name used in emitted events and outcomes.
    public let name: String

    /// Async step action.
    public let action: @Sendable () async throws -> Void

    /// Creates a post-success mutation step.
    @preconcurrency
    public init(
        name: String,
        action: @escaping @Sendable () async throws -> Void
    ) {
        self.name = name
        self.action = action
    }
}
