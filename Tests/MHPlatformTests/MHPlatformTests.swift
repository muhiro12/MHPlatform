import MHPlatform
import Testing

struct MHPlatformTests {
    @Test
    func full_platform_umbrella_exports_runtime_and_core_surface() {
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
            MHLogPolicy.self,
            MHLoggerFactory.self,
            MHLogRuntimeState.self,
            MHLoggingBootstrap.self
        ]
        let exportedTypes =
            runtimeSurface +
            coreSurface

        #expect(exportedTypes.count == 30)
    }

    @Test
    func full_platform_umbrella_exports_optional_ui_and_shell_surface() {
        let optionalUISurface: [Any.Type] = [
            MHOptionalCodablePreference<String>.self,
            MHCodablePreference<String>.self,
            MHLogConsoleView.self
        ]
        let optionalShellSurface: [Any.Type] = [
            MHMutationAdapter<String>.self,
            MHMutationWorkflowLogger.self,
            MHMutationStepListBuilder.self,
            MHMutationRetryPolicy.self,
            MHReviewPolicy.self,
            MHReviewRequester.self,
            MHReviewRequestOutcome.self,
            MHReviewFlow.self
        ]
        let exportedTypes =
            optionalUISurface +
            optionalShellSurface

        #expect(exportedTypes.count == 11)
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
