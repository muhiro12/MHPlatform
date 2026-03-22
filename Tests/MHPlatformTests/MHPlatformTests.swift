import MHPlatform
import Testing

struct MHPlatformTests {
    @Test
    func full_platform_umbrella_matches_app_composition_surface() {
        let runtimeSurface: [Any.Type] = [
            MHAppRuntimeCore.MHAppRuntime.self,
            MHAppRuntimeCore.MHAppRuntimeBootstrap.self
        ]
        let coreSurface: [Any.Type] = [
            MHDeepLinkConfiguration.self,
            MHReminderPolicy.self,
            MHNotificationPayload.self,
            MHRouteExecutionOutcome<Int>.self,
            MHObservableRouteInbox<Int>.self,
            MHStoreMigrationPlan.self,
            MHPreferenceStore.self,
            MHLogPolicy.self,
            MHLoggerFactory.self
        ]
        let optionalShellSurface: [Any.Type] = [
            MHMutationAdapter<String>.self,
            MHMutationStepListBuilder.self,
            MHMutationRetryPolicy.self,
            MHReviewPolicy.self
        ]
        let exportedTypes =
            runtimeSurface +
            coreSurface +
            optionalShellSurface

        #expect(exportedTypes.count == 15)
    }
}
