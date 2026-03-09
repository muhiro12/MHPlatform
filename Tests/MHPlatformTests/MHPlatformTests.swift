import MHPlatform
import Testing

struct MHPlatformTests {
    @Test
    func umbrella_import_exposes_public_modules() {
        let exportedTypes: [Any.Type] = [
            MHAppRuntimeCore.MHAppRuntime.self,
            MHAppRuntimeCore.MHAppRuntimeBootstrap.self,
            MHDeepLinkConfiguration.self,
            MHReminderPolicy.self,
            MHNotificationPayload.self,
            MHMutationAdapter<String>.self,
            MHMutationStepListBuilder.self,
            MHMutationRetryPolicy.self,
            MHRouteExecutionOutcome<Int>.self,
            MHObservableRouteInbox<Int>.self,
            MHStoreMigrationPlan.self,
            MHPreferenceStore.self,
            MHReviewPolicy.self,
            MHLogPolicy.self,
            MHLoggerFactory.self
        ]

        #expect(exportedTypes.count == 15)
    }
}
