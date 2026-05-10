import Foundation

/// Ordered lifecycle task executed by `MHAppRuntimeLifecycle`.
public struct MHAppRuntimeTask: Sendable, Hashable {
    /// Main-actor task action.
    public typealias Action = @MainActor @Sendable () async -> Void

    /// Main-actor task action that can read the owning app runtime.
    public typealias RuntimeAction = @MainActor @Sendable (MHAppRuntime) async -> Void

    /// Stable task name for debugging and test expectations.
    public let name: String

    private let taskAction: TaskAction

    /// Creates a runtime lifecycle task.
    @preconcurrency
    public init(
        name: String,
        action: @escaping Action
    ) {
        self.name = name
        self.taskAction = .plain(action)
    }

    /// Creates a runtime lifecycle task that can read the owning runtime.
    @preconcurrency
    public static func runtime(
        name: String,
        action: @escaping RuntimeAction
    ) -> Self {
        .init(
            name: name,
            taskAction: .runtime(action)
        )
    }

    public static func == (
        lhs: Self,
        rhs: Self
    ) -> Bool {
        lhs.name == rhs.name
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }

    @MainActor
    func run(runtime: MHAppRuntime) async {
        switch taskAction {
        case let .plain(action):
            await action()
        case let .runtime(action):
            await action(runtime)
        }
    }
}

private extension MHAppRuntimeTask {
    enum TaskAction: Sendable {
        case plain(Action)
        case runtime(RuntimeAction)
    }

    init(
        name: String,
        taskAction: TaskAction
    ) {
        self.name = name
        self.taskAction = taskAction
    }
}
