import MHRemoteUpdate

/// One app-owned dependency per process. UI observes updates.evaluation; intents call the same save.
@MainActor
struct JournalWriteOperations {
    let updates: MHRemoteUpdateAdapter

    /// Use from the startup and scene-activation hooks.
    func becameActive() async throws {
        try await updates.prepare()
    }

    /// An explicit retry follows the same preparation path.
    func retry() async throws {
        try await updates.prepare()
    }

    func save<Value>(
        policy: MHRemoteUpdateOperationPolicy,
        mutation: () throws -> Value,
        afterSuccess: () -> Void
    ) async throws -> Value {
        let value = try await updates.perform(policy: policy, mutation)
        afterSuccess()
        return value
    }
}
