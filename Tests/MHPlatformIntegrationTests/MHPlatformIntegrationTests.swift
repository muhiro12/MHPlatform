import SwiftUI
import Testing

@MainActor
struct MHPlatformIntegrationTests {
    @Test
    func runtime_lifecycle_drains_notification_route_and_runs_mutation_workflow() async {
        let harness = makeHarness()

        await harness.lifecycle.handleInitialAppearance()
        await harness.lifecycle.handleScenePhase(.active)

        await assertExpectedState(for: harness)
    }
}
