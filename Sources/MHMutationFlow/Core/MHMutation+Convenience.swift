/// Convenience builders for synchronous and main-actor mutations.
public extension MHMutation {
    /// Creates a mutation from a synchronous operation.
    static func sync(
        name: String,
        operation: @escaping @Sendable () throws -> Value
    ) -> Self {
        .init(name: name) {
            try operation()
        }
    }

    /// Creates a mutation from a synchronous main-actor operation.
    @preconcurrency
    static func mainActor(
        name: String,
        operation: @escaping @MainActor @Sendable () throws -> Value
    ) -> Self {
        .init(name: name) {
            try await MainActor.run {
                try operation()
            }
        }
    }

    /// Creates a mutation from an asynchronous main-actor operation.
    @preconcurrency
    static func mainActor(
        name: String,
        operation: @escaping @MainActor @Sendable () async throws -> Value
    ) -> Self {
        .init(name: name) {
            try await operation()
        }
    }
}
