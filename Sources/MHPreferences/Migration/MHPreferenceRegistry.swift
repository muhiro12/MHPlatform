import Foundation

/// App-owned current storage descriptors and their migration-state descriptor.
public struct MHPreferenceRegistry: Sendable {
    /// The complete current storage allowlist, including external raw descriptors.
    public let descriptors: [any MHStorageDescriptorProtocol]

    /// The caller-owned slot used to record completed migration steps.
    public let migrationStateDescriptor: MHPreferenceMigrationStateDescriptor

    /// Creates a registry without reading or changing defaults.
    public init(
        descriptors: [any MHStorageDescriptorProtocol],
        migrationStateDescriptor: MHPreferenceMigrationStateDescriptor
    ) {
        self.descriptors = descriptors
        self.migrationStateDescriptor = migrationStateDescriptor
    }

    /// Migrates and cleans up before returning, without a task or blocking bridge.
    ///
    /// Built-in moves support synchronous execution. An unfinished async-only
    /// custom step fails before migration or cleanup. Inspect the outcome before
    /// constructing preference consumers, and serialize runs per defaults domain.
    @preconcurrency
    public func runSynchronously(
        standardDomainName: String? = Bundle.main.bundleIdentifier,
        migrationStore: MHPreferenceStore = .init(),
        stateStore: MHPreferenceStore = .init(),
        onMigrationEvent: @Sendable (MHPreferenceMigrationEvent) -> Void = { _ in () }
    ) -> MHPreferenceLifecycleOutcome {
        let steps = descriptors.flatMap { descriptor in
            descriptor.migrationSteps(store: migrationStore)
        }
        let migrationOutcome = MHPreferenceMigrationService.runSynchronously(
            steps: steps,
            stateDescriptor: migrationStateDescriptor,
            stateStore: stateStore,
            onEvent: onMigrationEvent
        )
        return MHPreferenceLifecycleService.finish(
            migrationOutcome: migrationOutcome,
            descriptors: descriptors,
            migrationStateDescriptor: migrationStateDescriptor,
            standardDomainName: standardDomainName
        )
    }

    /// Runs the same registry through the asynchronous lifecycle service.
    @preconcurrency
    public func run(
        standardDomainName: String? = Bundle.main.bundleIdentifier,
        migrationStore: MHPreferenceStore = .init(),
        stateStore: MHPreferenceStore = .init(),
        onMigrationEvent: @Sendable (MHPreferenceMigrationEvent) -> Void = { _ in () }
    ) async -> MHPreferenceLifecycleOutcome {
        await MHPreferenceLifecycleService.run(
            descriptors: descriptors,
            migrationStateDescriptor: migrationStateDescriptor,
            standardDomainName: standardDomainName,
            migrationStore: migrationStore,
            stateStore: stateStore,
            onMigrationEvent: onMigrationEvent
        )
    }
}
