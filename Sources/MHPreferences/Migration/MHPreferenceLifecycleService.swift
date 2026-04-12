import Foundation

/// Runs app-owned descriptor migration followed by unknown-key cleanup.
public enum MHPreferenceLifecycleService {
    /// Migrates all legacy sources declared on the provided descriptors and then
    /// prunes stale keys from each touched defaults domain.
    @preconcurrency
    public static func run<Descriptors: Sequence>(
        descriptors: Descriptors,
        migrationStateDescriptor: MHPreferenceMigrationStateDescriptor,
        standardDomainName: String? = Bundle.main.bundleIdentifier,
        migrationStore: MHPreferenceStore = .init(),
        stateStore: MHPreferenceStore = .init(),
        onMigrationEvent: @Sendable (MHPreferenceMigrationEvent) -> Void = { _ in () }
    ) async -> MHPreferenceLifecycleOutcome where Descriptors.Element: MHStorageDescriptorProtocol {
        await run(
            descriptors: descriptors.map { descriptor in
                descriptor as any MHStorageDescriptorProtocol
            },
            migrationStateDescriptor: migrationStateDescriptor,
            standardDomainName: standardDomainName,
            migrationStore: migrationStore,
            stateStore: stateStore,
            onMigrationEvent: onMigrationEvent
        )
    }

    /// Migrates all legacy sources declared on the provided descriptors and then
    /// prunes stale keys from each touched defaults domain.
    @preconcurrency
    public static func run(
        descriptors: [any MHStorageDescriptorProtocol],
        migrationStateDescriptor: MHPreferenceMigrationStateDescriptor,
        standardDomainName: String? = Bundle.main.bundleIdentifier,
        migrationStore: MHPreferenceStore = .init(),
        stateStore: MHPreferenceStore = .init(),
        onMigrationEvent: @Sendable (MHPreferenceMigrationEvent) -> Void = { _ in () }
    ) async -> MHPreferenceLifecycleOutcome {
        let migrationSteps = descriptors.flatMap { descriptor in
            descriptor.migrationSteps(store: migrationStore)
        }
        let migrationOutcome = await MHPreferenceMigrationService.run(
            steps: migrationSteps,
            stateDescriptor: migrationStateDescriptor,
            stateStore: stateStore,
            onEvent: onMigrationEvent
        )

        guard case .succeeded = migrationOutcome else {
            return .init(
                migrationOutcome: migrationOutcome,
                cleanupReports: []
            )
        }

        let cleanupTargets = cleanupTargets(
            descriptors: descriptors,
            migrationStateDescriptor: migrationStateDescriptor,
            standardDomainName: standardDomainName
        )
        let cleanupReports = cleanupTargets.map { target in
            let report = MHUserDefaultsCleanupService.removeUnknownKeys(
                from: target.selection.resolveUserDefaults(),
                domainName: target.domainName,
                knownDescriptors: knownDescriptors(
                    for: target,
                    descriptors: descriptors,
                    migrationStateDescriptor: migrationStateDescriptor,
                    standardDomainName: standardDomainName
                )
            )
            return MHPreferenceDomainCleanupReport(
                selection: target.selection,
                domainName: target.domainName,
                report: report
            )
        }

        return .init(
            migrationOutcome: migrationOutcome,
            cleanupReports: cleanupReports
        )
    }
}

private extension MHPreferenceLifecycleService {
    struct CleanupTarget: Hashable {
        let comparisonKey: String
        let selection: MHUserDefaultsSelection
        let domainName: String
    }

    static func cleanupTargets(
        descriptors: [any MHStorageDescriptorProtocol],
        migrationStateDescriptor: MHPreferenceMigrationStateDescriptor,
        standardDomainName: String?
    ) -> [CleanupTarget] {
        var targets = [CleanupTarget]()

        for descriptor in descriptors {
            appendCleanupTarget(
                selection: descriptor.defaultSelection,
                standardDomainName: standardDomainName,
                to: &targets
            )

            let legacySources = (descriptor as? any MHPreferenceDescriptorProtocol)?
                .legacySources ?? []
            for legacySource in legacySources {
                appendCleanupTarget(
                    selection: legacySource.selection,
                    standardDomainName: standardDomainName,
                    to: &targets
                )
            }
        }

        appendCleanupTarget(
            selection: migrationStateDescriptor.defaultSelection,
            standardDomainName: standardDomainName,
            to: &targets
        )

        return targets
    }

    static func appendCleanupTarget(
        selection: MHUserDefaultsSelection,
        standardDomainName: String?,
        to targets: inout [CleanupTarget]
    ) {
        let target = CleanupTarget(
            comparisonKey: selection.normalizedComparisonKey(
                standardDomainName: standardDomainName
            ),
            selection: selection,
            domainName: selection.persistentDomainName(
                standardDomainName: standardDomainName
            )
        )

        guard targets.contains(target) == false else {
            return
        }

        targets.append(target)
    }

    static func knownDescriptors(
        for target: CleanupTarget,
        descriptors: [any MHStorageDescriptorProtocol],
        migrationStateDescriptor: MHPreferenceMigrationStateDescriptor,
        standardDomainName: String?
    ) -> [any MHStorageDescriptorProtocol] {
        var result = descriptors.filter { descriptor in
            descriptor.defaultSelection.normalizedComparisonKey(
                standardDomainName: standardDomainName
            ) == target.comparisonKey
        }

        if migrationStateDescriptor.defaultSelection.normalizedComparisonKey(
            standardDomainName: standardDomainName
        ) == target.comparisonKey {
            result.append(migrationStateDescriptor)
        }

        return result
    }
}
