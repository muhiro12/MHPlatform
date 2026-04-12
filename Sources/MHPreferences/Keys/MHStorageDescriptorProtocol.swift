/// A caller-owned storage descriptor backed by `UserDefaults`.
public protocol MHStorageDescriptorProtocol: Sendable {
    /// Fully composed storage key name used by `UserDefaults`.
    var storageKey: String { get }

    /// The default defaults selection used when no explicit store is injected.
    var defaultSelection: MHUserDefaultsSelection { get }

    /// Migration steps implied by this descriptor.
    func migrationSteps(
        store: MHPreferenceStore
    ) -> [MHPreferenceMigrationStep]
}

public extension MHStorageDescriptorProtocol {
    /// Returns no migration steps by default.
    func migrationSteps(
        store _: MHPreferenceStore
    ) -> [MHPreferenceMigrationStep] {
        []
    }
}
