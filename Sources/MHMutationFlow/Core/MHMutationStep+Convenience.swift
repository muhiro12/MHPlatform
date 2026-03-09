/// Convenience builders for synchronous and main-actor mutation steps.
public extension MHMutationStep {
    /// Creates a post-success step from a synchronous action.
    static func sync(
        name: String,
        action: @escaping @Sendable () throws -> Void
    ) -> Self {
        .init(name: name) {
            try action()
        }
    }

    /// Creates a post-success step from a synchronous main-actor action.
    @preconcurrency
    static func mainActor(
        name: String,
        action: @escaping @MainActor @Sendable () throws -> Void
    ) -> Self {
        .init(name: name) {
            try await MainActor.run {
                try action()
            }
        }
    }

    /// Creates a post-success step from an asynchronous main-actor action.
    @preconcurrency
    static func mainActor(
        name: String,
        action: @escaping @MainActor @Sendable () async throws -> Void
    ) -> Self {
        .init(name: name) {
            try await action()
        }
    }
}
