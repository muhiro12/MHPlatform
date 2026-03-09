import Foundation

/// Defines legacy and current store URLs used for migration.
public struct MHStoreMigrationPlan: Sendable {
    /// Legacy store URL that may still contain data.
    public let legacyStoreURL: URL

    /// Current canonical store URL.
    public let currentStoreURL: URL

    /// Creates a migration plan.
    public init(
        legacyStoreURL: URL,
        currentStoreURL: URL
    ) {
        self.legacyStoreURL = legacyStoreURL
        self.currentStoreURL = currentStoreURL
    }
}
