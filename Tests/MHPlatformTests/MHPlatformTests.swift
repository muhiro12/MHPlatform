import MHPlatform
import Testing

struct MHPlatformTests {
    @Test
    func umbrella_import_exposes_public_modules() {
        let exportedTypes: [Any.Type] = [
            MHAppRuntime.self,
            MHDeepLinkConfiguration.self,
            MHReminderPolicy.self,
            MHNotificationPayload.self,
            MHMutationAdapter<String>.self,
            MHMutationRetryPolicy.self,
            MHRouteExecutionOutcome<Int>.self,
            MHStoreMigrationPlan.self,
            MHPreferenceStore.self,
            MHReviewPolicy.self,
            MHLogPolicy.self,
            MHLoggerFactory.self
        ]

        #expect(exportedTypes.count == 12)
    }
}
