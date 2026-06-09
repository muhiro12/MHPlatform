import MHPlatform
import Testing

struct MHPlatformTests {
    @Test
    func full_platform_umbrella_matches_app_composition_surface() {
        let runtimeSurface: [Any.Type] = [
            MHAppRuntime.self,
            MHAppRuntimeBootstrap.self
        ]
        let coreSurface: [Any.Type] = [
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
        let optionalShellSurface: [Any.Type] = [
            MHMutationAdapter<String>.self,
            MHMutationWorkflowLogger.self,
            MHMutationStepListBuilder.self,
            MHMutationRetryPolicy.self,
            MHReviewPolicy.self
        ]
        let exportedTypes =
            runtimeSurface +
            coreSurface +
            optionalShellSurface

        #expect(exportedTypes.count == 39)
    }

    @MainActor
    @Test
    func full_platform_umbrella_keeps_default_runtime_convenience_apis() {
        let configuration = MHAppConfiguration(
            subscriptionProductIDs: ["premium.monthly"],
            showsLicenses: false
        )

        let runtime = MHAppRuntime(configuration: configuration)
        let bootstrap = MHAppRuntimeBootstrap(configuration: configuration)

        #expect(runtime.configuration == configuration)
        #expect(bootstrap.runtime.configuration == configuration)
    }
}
