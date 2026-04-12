/// Outcome of running descriptor-driven migration and cleanup.
public struct MHPreferenceLifecycleOutcome: Sendable {
    /// The ordered migration result.
    public let migrationOutcome: MHPreferenceMigrationOutcome

    /// Cleanup reports for each touched defaults domain.
    public let cleanupReports: [MHPreferenceDomainCleanupReport]

    /// Creates a lifecycle outcome.
    public init(
        migrationOutcome: MHPreferenceMigrationOutcome,
        cleanupReports: [MHPreferenceDomainCleanupReport]
    ) {
        self.migrationOutcome = migrationOutcome
        self.cleanupReports = cleanupReports
    }
}
