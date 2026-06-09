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
            MHStoreRelocationPlan.self,
            MHStoreRelocationSkipReason.self,
            MHStoreRelocationOutcome.self,
            MHLegacyStoreCleanupOutcome.self,
            MHStoreRelocationService.self,
            MHDestructiveResetStep.self,
            MHDestructiveResetService.self,
            MHDestructiveResetOutcome.self,
            MHDestructiveResetEvent.self,
            MHPreferenceStore.self,
            MHPreferenceDescriptors.self,
            MHUserDefaultsSelection.self,
            MHRawStorageDescriptor.self,
            MHDatePreferenceDescriptor.self,
            MHUserDefaultsCleanupReport.self,
            MHUserDefaultsCleanupService.self,
            MHPreferenceDomainCleanupReport.self,
            MHPreferenceLifecycleOutcome.self,
            MHPreferenceLifecycleService.self,
            MHOptionalCodablePreference<String>.self,
            MHCodablePreference<String>.self,
            MHLogPolicy.self,
            MHLoggerFactory.self,
            MHLogRuntimeState.self,
            MHLoggingBootstrap.self,
            MHPersistentIdentifierCodec.self,
            MHPersistentIdentifierCodecError.self
        ]

        #expect(exportedCoreSafeTypes.count == 32)
    }
}
