import MHPlatformCore
import Testing

struct MHPlatformCoreTests {
    @Test
    func umbrella_import_exposes_shared_package_modules() {
        let exportedTypes: [Any.Type] = [
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

        #expect(exportedTypes.count == 9)
    }
}
