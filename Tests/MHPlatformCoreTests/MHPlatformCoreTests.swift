import MHPlatformCore
import Testing

struct MHPlatformCoreTests {
    @Test
    func shared_package_umbrella_matches_core_safe_surface() {
        let exportedCoreSafeTypes: [Any.Type] = [
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

        #expect(exportedCoreSafeTypes.count == 9)
    }
}
