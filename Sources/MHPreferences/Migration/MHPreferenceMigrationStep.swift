import Foundation

/// A single app-owned preference migration step.
public struct MHPreferenceMigrationStep: Sendable {
    public let id: String

    let action: @Sendable () async throws -> Void

    /// Creates a migration step with a stable identifier.
    @preconcurrency
    public init(
        id: String,
        action: @escaping @Sendable () async throws -> Void
    ) {
        precondition(id.isEmpty == false)
        self.id = id
        self.action = action
    }

    /// Moves a boolean value from a legacy storage slot when the destination is still empty.
    public static func move(
        id: String,
        from source: MHLegacyStorageReference,
        to target: MHBoolPreferenceDescriptor,
        store: MHPreferenceStore = .init()
    ) -> Self {
        let sourceDescriptor = MHBoolPreferenceDescriptor(
            storageKey: source.storageKey,
            defaultSelection: source.selection,
            default: target.defaultValue
        )
        return makeMoveStep(id: id) {
            guard store.contains(sourceDescriptor) else {
                return
            }
            let value = store.bool(for: sourceDescriptor)
            store.set(value, for: target)
            store.remove(sourceDescriptor)
        } targetCheck: {
            store.contains(target)
        }
    }

    /// Moves an integer value from a legacy storage slot when the destination is still empty.
    public static func move(
        id: String,
        from source: MHLegacyStorageReference,
        to target: MHIntPreferenceDescriptor,
        store: MHPreferenceStore = .init()
    ) -> Self {
        let sourceDescriptor = MHIntPreferenceDescriptor(
            storageKey: source.storageKey,
            defaultSelection: source.selection,
            default: target.defaultValue
        )
        return makeMoveStep(id: id) {
            guard store.contains(sourceDescriptor) else {
                return
            }
            let value = store.int(for: sourceDescriptor)
            store.set(value, for: target)
            store.remove(sourceDescriptor)
        } targetCheck: {
            store.contains(target)
        }
    }

    /// Moves an optional-string value from a legacy storage slot when the destination is still empty.
    public static func move(
        id: String,
        from source: MHLegacyStorageReference,
        to target: MHStringPreferenceDescriptor,
        store: MHPreferenceStore = .init()
    ) -> Self {
        let sourceDescriptor = MHStringPreferenceDescriptor(
            storageKey: source.storageKey,
            defaultSelection: source.selection
        )
        return makeMoveStep(id: id) {
            guard store.contains(sourceDescriptor) else {
                return
            }
            let value = store.string(for: sourceDescriptor)
            store.set(value, for: target)
            store.remove(sourceDescriptor)
        } targetCheck: {
            store.contains(target)
        }
    }

    /// Moves a codable value from a legacy storage slot when the destination is still empty.
    public static func move<Value: Codable & Sendable>(
        id: String,
        from source: MHLegacyStorageReference,
        to target: MHCodablePreferenceDescriptor<Value>,
        store: MHPreferenceStore = .init()
    ) -> Self {
        let sourceDescriptor = MHCodablePreferenceDescriptor<Value>(
            storageKey: source.storageKey,
            defaultSelection: source.selection
        )
        return makeMoveStep(id: id) {
            guard let value = store.codable(for: sourceDescriptor) else {
                return
            }
            store.setCodable(value, for: target)
            store.remove(sourceDescriptor)
        } targetCheck: {
            store.contains(target)
        }
    }

    /// Runs unknown-key cleanup for a caller-owned domain.
    public static func cleanupDomain<Descriptors: Sequence>(
        id: String,
        from userDefaults: UserDefaults,
        domainName: String,
        knownDescriptors: Descriptors
    ) -> Self where Descriptors.Element: MHStorageDescriptorProtocol {
        let sendableUserDefaults = SendableUserDefaultsBox(
            userDefaults: userDefaults
        )
        let cleanupDescriptors = knownDescriptors.map { descriptor in
            MHRawStorageDescriptor(
                storageKey: descriptor.storageKey,
                defaultSelection: descriptor.defaultSelection
            )
        }
        return .init(id: id) {
            _ = MHUserDefaultsCleanupService.removeUnknownKeys(
                from: sendableUserDefaults.userDefaults,
                domainName: domainName,
                knownKeys: cleanupDescriptors
            )
        }
    }

    /// Runs unknown-key cleanup for a caller-owned domain.
    public static func cleanupDomain(
        id: String,
        from userDefaults: UserDefaults,
        domainName: String,
        knownDescriptors: [any MHStorageDescriptorProtocol]
    ) -> Self {
        let sendableUserDefaults = SendableUserDefaultsBox(
            userDefaults: userDefaults
        )
        let cleanupDescriptors = knownDescriptors.map { descriptor in
            MHRawStorageDescriptor(
                storageKey: descriptor.storageKey,
                defaultSelection: descriptor.defaultSelection
            )
        }
        return .init(id: id) {
            _ = MHUserDefaultsCleanupService.removeUnknownKeys(
                from: sendableUserDefaults.userDefaults,
                domainName: domainName,
                knownKeys: cleanupDescriptors
            )
        }
    }
}

private extension MHPreferenceMigrationStep {
    struct SendableUserDefaultsBox: @unchecked Sendable {
        let userDefaults: UserDefaults
    }

    static func makeMoveStep(
        id: String,
        action: @escaping @Sendable () -> Void,
        targetCheck: @escaping @Sendable () -> Bool
    ) -> Self {
        .init(id: id) {
            guard targetCheck() == false else {
                return
            }

            action()
        }
    }
}

public extension MHBoolPreferenceDescriptor {
    /// Builds move steps for all legacy storage slots declared on this descriptor.
    func migrationSteps(
        store: MHPreferenceStore = .init()
    ) -> [MHPreferenceMigrationStep] {
        legacySources.map { source in
            .move(
                id: source.stepID(for: storageKey),
                from: source,
                to: self,
                store: store
            )
        }
    }
}

public extension MHIntPreferenceDescriptor {
    /// Builds move steps for all legacy storage slots declared on this descriptor.
    func migrationSteps(
        store: MHPreferenceStore = .init()
    ) -> [MHPreferenceMigrationStep] {
        legacySources.map { source in
            .move(
                id: source.stepID(for: storageKey),
                from: source,
                to: self,
                store: store
            )
        }
    }
}

public extension MHStringPreferenceDescriptor {
    /// Builds move steps for all legacy storage slots declared on this descriptor.
    func migrationSteps(
        store: MHPreferenceStore = .init()
    ) -> [MHPreferenceMigrationStep] {
        legacySources.map { source in
            .move(
                id: source.stepID(for: storageKey),
                from: source,
                to: self,
                store: store
            )
        }
    }
}

public extension MHCodablePreferenceDescriptor {
    /// Builds move steps for all legacy storage slots declared on this descriptor.
    func migrationSteps(
        store: MHPreferenceStore = .init()
    ) -> [MHPreferenceMigrationStep] {
        legacySources.map { source in
            .move(
                id: source.stepID(for: storageKey),
                from: source,
                to: self,
                store: store
            )
        }
    }
}

private extension MHLegacyStorageReference {
    func stepID(
        for targetStorageKey: String
    ) -> String {
        "move.\(selection.stepIDComponent).\(storageKey).to.\(targetStorageKey)"
    }
}

private extension MHUserDefaultsSelection {
    var stepIDComponent: String {
        switch self {
        case .standard:
            "standard"
        case let .suite(suiteName):
            "suite.\(suiteName)"
        }
    }
}
