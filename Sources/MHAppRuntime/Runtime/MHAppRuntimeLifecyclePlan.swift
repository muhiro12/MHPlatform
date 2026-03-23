/// Configuration for `MHAppRuntimeLifecycle`.
public struct MHAppRuntimeLifecyclePlan: Sendable, Hashable {
    /// Empty lifecycle plan.
    public static let empty = Self()

    /// Ordered tasks that run once after the initial appearance hook.
    public let startupTasks: [MHAppRuntimeTask]

    /// Ordered tasks that run when the app becomes active.
    public let activeTasks: [MHAppRuntimeTask]

    /// Whether the first active phase after view attachment should skip
    /// `activeTasks`.
    public let skipFirstActivePhase: Bool

    /// Creates a lifecycle plan.
    public init(
        startupTasks: [MHAppRuntimeTask] = [],
        activeTasks: [MHAppRuntimeTask] = [],
        skipFirstActivePhase: Bool = false
    ) {
        self.startupTasks = startupTasks
        self.activeTasks = activeTasks
        self.skipFirstActivePhase = skipFirstActivePhase
    }

    /// Creates a lifecycle plan that prepends shared tasks to startup and
    /// active phases.
    public init(
        commonTasks: [MHAppRuntimeTask] = [],
        startupTasks: [MHAppRuntimeTask] = [],
        activeTasks: [MHAppRuntimeTask] = [],
        skipFirstActivePhase: Bool = false
    ) {
        self.startupTasks = commonTasks + startupTasks
        self.activeTasks = commonTasks + activeTasks
        self.skipFirstActivePhase = skipFirstActivePhase
    }
}
