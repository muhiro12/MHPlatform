import SwiftUI

@MainActor
private struct MHAppRuntimeLifecycleModifier: ViewModifier {
    @Environment(\.scenePhase)
    private var scenePhase

    @State private var lifecycle: MHAppRuntimeLifecycle

    init(
        runtime: MHAppRuntime,
        plan: MHAppRuntimeLifecyclePlan
    ) {
        _lifecycle = .init(
            initialValue: .init(
                runtime: runtime,
                plan: plan
            )
        )
    }

    func body(content: Content) -> some View {
        content
            .task {
                await lifecycle.handleInitialAppearance()
            }
            .onChange(of: scenePhase) {
                Task {
                    await lifecycle.handleScenePhase(scenePhase)
                }
            }
    }
}

public extension View {
    /// Applies runtime startup and active-phase lifecycle handling to a view.
    @MainActor
    func mhAppRuntimeLifecycle(
        runtime: MHAppRuntime,
        plan: MHAppRuntimeLifecyclePlan = .empty
    ) -> some View {
        modifier(
            MHAppRuntimeLifecycleModifier(
                runtime: runtime,
                plan: plan
            )
        )
    }
}
