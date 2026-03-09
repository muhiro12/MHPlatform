import SwiftUI

/// Coordinates runtime startup and app-active lifecycle tasks.
@MainActor
@preconcurrency
public final class MHAppRuntimeLifecycle {
    private let runtime: MHAppRuntime
    private let plan: MHAppRuntimeLifecyclePlan

    private var hasHandledInitialAppearance = false
    private var hasObservedActivePhase = false

    /// Creates a lifecycle coordinator for a runtime.
    public init(
        runtime: MHAppRuntime,
        plan: MHAppRuntimeLifecyclePlan = .empty
    ) {
        self.runtime = runtime
        self.plan = plan
    }

    /// Starts the runtime and runs startup tasks once.
    public func handleInitialAppearance() async {
        guard hasHandledInitialAppearance == false else {
            return
        }

        hasHandledInitialAppearance = true
        runtime.startIfNeeded()
        await runTasks(plan.startupTasks)
    }

    /// Starts the runtime and runs active-phase tasks when the app becomes
    /// active.
    public func handleScenePhase(_ scenePhase: ScenePhase) async {
        guard scenePhase == .active else {
            return
        }

        runtime.startIfNeeded()

        if hasObservedActivePhase == false {
            hasObservedActivePhase = true

            if plan.skipFirstActivePhase {
                return
            }
        }

        await runTasks(plan.activeTasks)
    }
}

private extension MHAppRuntimeLifecycle {
    func runTasks(_ tasks: [MHAppRuntimeTask]) async {
        for task in tasks {
            await task.run()
        }
    }
}
