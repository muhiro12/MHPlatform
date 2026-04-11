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
            MHDestructiveResetStep.self,
            MHDestructiveResetService.self,
            MHDestructiveResetOutcome.self,
            MHDestructiveResetEvent.self,
            MHPreferenceStore.self,
            MHUserDefaultsSelection.self,
            MHRawStorageKey.self,
            MHUserDefaultsCleanupReport.self,
            MHUserDefaultsCleanupService.self,
            MHLogPolicy.self,
            MHLoggerFactory.self,
            MHLogRuntimeState.self,
            MHLoggingBootstrap.self
        ]

        #expect(exportedCoreSafeTypes.count == 18)
    }
}
