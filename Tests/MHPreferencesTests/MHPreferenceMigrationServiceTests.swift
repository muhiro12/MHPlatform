#if canImport(Foundation)
import Foundation
import MHPreferences
import Testing

struct MHPreferenceMigrationServiceTests {}

private extension MHPreferenceMigrationServiceTests {
    enum Constants {
        static let storageKeyPrefix = "tests.preference-migration"
    }

    struct Payload: Codable, Equatable, Sendable {
        let title: String
        let count: Int
    }

    struct TestError: Error {}
}

extension MHPreferenceMigrationServiceTests {
    @Test
    func move_bool_uses_descriptor_default_selections_across_domains() async throws {
        let oldSuiteName = "MHPreferenceMigrationServiceTests.old.\(UUID().uuidString)"
        let newSuiteName = "MHPreferenceMigrationServiceTests.new.\(UUID().uuidString)"
        let stateSuiteName = "MHPreferenceMigrationServiceTests.state.\(UUID().uuidString)"
        let oldDefaults = try makeUserDefaults(suiteName: oldSuiteName)
        let newDefaults = try makeUserDefaults(suiteName: newSuiteName)
        let stateDefaults = try makeUserDefaults(suiteName: stateSuiteName)
        defer {
            oldDefaults.removePersistentDomain(forName: oldSuiteName)
            newDefaults.removePersistentDomain(forName: newSuiteName)
            stateDefaults.removePersistentDomain(forName: stateSuiteName)
        }

        let legacySource = MHLegacyStorageReference(
            storageKey: "\(Constants.storageKeyPrefix).legacy-bool",
            selection: .suite(oldSuiteName)
        )
        let target = makeBoolDescriptor(
            "current-bool",
            defaultSelection: .suite(newSuiteName),
            legacySources: [legacySource]
        )
        let stateDescriptor = makeStateDescriptor(
            "migration-state",
            defaultSelection: .suite(stateSuiteName)
        )
        let completedStepIDsDescriptor = makeCompletedStepIDsDescriptor(
            stateDescriptor
        )
        let steps = target.migrationSteps()

        oldDefaults.set(true, forKey: legacySource.storageKey)

        let outcome = await MHPreferenceMigrationService.run(
            steps: steps,
            stateDescriptor: stateDescriptor
        )

        #expect(oldDefaults.object(forKey: legacySource.storageKey) == nil)
        #expect(newDefaults.bool(forKey: target.storageKey))
        #expect(
            completedStepIDs(
                for: completedStepIDsDescriptor,
                in: stateDefaults
            ) == steps.map(\.id)
        )
        assertSucceeded(
            outcome,
            completedStepIDs: steps.map(\.id),
            skippedStepIDs: []
        )
    }

    @Test
    func completed_step_ids_skip_reruns() async throws {
        let suiteName = "MHPreferenceMigrationServiceTests.skip.\(UUID().uuidString)"
        let userDefaults = try makeUserDefaults(suiteName: suiteName)
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }

        let legacySource = MHLegacyStorageReference(
            storageKey: "\(Constants.storageKeyPrefix).skip-legacy",
            selection: .suite(suiteName)
        )
        let target = makeBoolDescriptor(
            "skip-current",
            defaultSelection: .suite(suiteName),
            legacySources: [legacySource]
        )
        let stateDescriptor = makeStateDescriptor(
            "skip-state",
            defaultSelection: .suite(suiteName)
        )
        let steps = target.migrationSteps()
        let moveStepID = try #require(steps.first?.id)

        userDefaults.set(true, forKey: legacySource.storageKey)
        _ = await MHPreferenceMigrationService.run(
            steps: steps,
            stateDescriptor: stateDescriptor
        )

        userDefaults.set(false, forKey: legacySource.storageKey)
        let outcome = await MHPreferenceMigrationService.run(
            steps: steps,
            stateDescriptor: stateDescriptor
        )

        #expect(userDefaults.bool(forKey: target.storageKey))
        #expect(userDefaults.bool(forKey: legacySource.storageKey) == false)

        assertSucceeded(
            outcome,
            completedStepIDs: [],
            skippedStepIDs: [moveStepID]
        )
    }

    @Test
    func move_codable_preserves_value_and_removes_source() async throws {
        let oldSuiteName = "MHPreferenceMigrationServiceTests.codable-old.\(UUID().uuidString)"
        let newSuiteName = "MHPreferenceMigrationServiceTests.codable-new.\(UUID().uuidString)"
        let oldDefaults = try makeUserDefaults(suiteName: oldSuiteName)
        let newDefaults = try makeUserDefaults(suiteName: newSuiteName)
        defer {
            oldDefaults.removePersistentDomain(forName: oldSuiteName)
            newDefaults.removePersistentDomain(forName: newSuiteName)
        }

        let legacySource = MHLegacyStorageReference(
            storageKey: "\(Constants.storageKeyPrefix).codable-legacy",
            selection: .suite(oldSuiteName)
        )
        let target = makeCodableDescriptor(
            "codable-current",
            defaultSelection: .suite(newSuiteName),
            legacySources: [legacySource]
        )
        let payload = Payload(
            title: "payload",
            count: 7
        )
        let steps = target.migrationSteps()

        setLegacyCodable(
            payload,
            for: legacySource,
            in: oldDefaults
        )

        let outcome = await MHPreferenceMigrationService.run(
            steps: steps,
            stateDescriptor: makeStateDescriptor(
                "codable-state",
                defaultSelection: .suite(newSuiteName)
            )
        )

        #expect(oldDefaults.object(forKey: legacySource.storageKey) == nil)
        #expect(
            MHPreferenceStore(userDefaults: newDefaults).codable(for: target)
                == payload
        )

        assertSucceeded(
            outcome,
            completedStepIDs: steps.map(\.id),
            skippedStepIDs: []
        )
    }
}

extension MHPreferenceMigrationServiceTests {
    @Test
    func cleanup_step_prunes_unknown_keys_after_move_when_state_descriptor_is_known() async throws {
        let suiteName = "MHPreferenceMigrationServiceTests.cleanup.\(UUID().uuidString)"
        let userDefaults = try makeUserDefaults(suiteName: suiteName)
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }

        let legacySource = MHLegacyStorageReference(
            storageKey: "\(Constants.storageKeyPrefix).cleanup-legacy",
            selection: .suite(suiteName)
        )
        let target = makeStringDescriptor(
            "cleanup-current",
            defaultSelection: .suite(suiteName),
            legacySources: [legacySource]
        )
        let stateDescriptor = makeStateDescriptor(
            "cleanup-state",
            defaultSelection: .suite(suiteName)
        )
        let moveSteps = target.migrationSteps()
        let cleanupStep = MHPreferenceMigrationStep.cleanupDomain(
            id: "cleanup-domain",
            from: userDefaults,
            domainName: suiteName,
            knownDescriptors: [target, stateDescriptor]
        )

        userDefaults.set("value", forKey: legacySource.storageKey)
        userDefaults.set("legacy", forKey: "tests.preference-migration.unknown")

        let outcome = await MHPreferenceMigrationService.run(
            steps: moveSteps + [cleanupStep],
            stateDescriptor: stateDescriptor
        )

        #expect(userDefaults.object(forKey: legacySource.storageKey) == nil)
        #expect(userDefaults.string(forKey: target.storageKey) == "value")
        #expect(userDefaults.object(forKey: "tests.preference-migration.unknown") == nil)
        #expect(userDefaults.object(forKey: stateDescriptor.storageKey) is Data)

        assertSucceeded(
            outcome,
            completedStepIDs: moveSteps.map(\.id) + [cleanupStep.id],
            skippedStepIDs: []
        )
    }

    @Test
    func failed_step_does_not_record_completion() async throws {
        let suiteName = "MHPreferenceMigrationServiceTests.failure.\(UUID().uuidString)"
        let userDefaults = try makeUserDefaults(suiteName: suiteName)
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }

        let stateDescriptor = makeStateDescriptor(
            "failure-state",
            defaultSelection: .suite(suiteName)
        )
        let completedStepIDsDescriptor = makeCompletedStepIDsDescriptor(
            stateDescriptor
        )

        let outcome = await MHPreferenceMigrationService.run(
            steps: [
                .init(id: "failing-step") {
                    throw TestError()
                }
            ],
            stateDescriptor: stateDescriptor
        )

        #expect(
            completedStepIDs(
                for: completedStepIDsDescriptor,
                in: userDefaults
            ).isEmpty
        )

        switch outcome {
        case .succeeded:
            Issue.record("Expected migration to fail.")
        case let .failed(error, failedStepID, completedStepIDs, skippedStepIDs):
            #expect(
                String(describing: error)
                    == String(describing: TestError())
            )
            #expect(failedStepID == "failing-step")
            #expect(completedStepIDs.isEmpty)
            #expect(skippedStepIDs.isEmpty)
        }
    }
}

private extension MHPreferenceMigrationServiceTests {
    func completedStepIDs(
        for descriptor: MHCodablePreferenceDescriptor<[String]>,
        in userDefaults: UserDefaults
    ) -> [String] {
        MHPreferenceStore(userDefaults: userDefaults).codable(
            for: descriptor
        ) ?? []
    }

    func assertSucceeded(
        _ outcome: MHPreferenceMigrationOutcome,
        completedStepIDs expectedCompletedStepIDs: [String],
        skippedStepIDs expectedSkippedStepIDs: [String]
    ) {
        switch outcome {
        case let .succeeded(completedStepIDs, skippedStepIDs):
            #expect(completedStepIDs == expectedCompletedStepIDs)
            #expect(skippedStepIDs == expectedSkippedStepIDs)
        case .failed:
            Issue.record("Expected migration to succeed.")
        }
    }

    func makeUserDefaults(
        suiteName: String
    ) throws -> UserDefaults {
        let userDefaults = try #require(
            UserDefaults(suiteName: suiteName)
        )
        userDefaults.removePersistentDomain(forName: suiteName)
        return userDefaults
    }

    func makeBoolDescriptor(
        _ name: String,
        defaultSelection: MHUserDefaultsSelection,
        legacySources: [MHLegacyStorageReference] = []
    ) -> MHBoolPreferenceDescriptor {
        .init(
            storageKey: "\(Constants.storageKeyPrefix).\(name)",
            defaultSelection: defaultSelection,
            legacySources: legacySources
        )
    }

    func makeStringDescriptor(
        _ name: String,
        defaultSelection: MHUserDefaultsSelection,
        legacySources: [MHLegacyStorageReference] = []
    ) -> MHStringPreferenceDescriptor {
        .init(
            storageKey: "\(Constants.storageKeyPrefix).\(name)",
            defaultSelection: defaultSelection,
            legacySources: legacySources
        )
    }

    func makeCodableDescriptor(
        _ name: String,
        defaultSelection: MHUserDefaultsSelection,
        legacySources: [MHLegacyStorageReference] = []
    ) -> MHCodablePreferenceDescriptor<Payload> {
        .init(
            storageKey: "\(Constants.storageKeyPrefix).\(name)",
            defaultSelection: defaultSelection,
            legacySources: legacySources
        )
    }

    func makeStateDescriptor(
        _ name: String,
        defaultSelection: MHUserDefaultsSelection
    ) -> MHPreferenceMigrationStateDescriptor {
        .init(
            storageKey: "\(Constants.storageKeyPrefix).\(name)",
            defaultSelection: defaultSelection
        )
    }

    func makeCompletedStepIDsDescriptor(
        _ stateDescriptor: MHPreferenceMigrationStateDescriptor
    ) -> MHCodablePreferenceDescriptor<[String]> {
        .init(
            storageKey: stateDescriptor.storageKey,
            defaultSelection: stateDescriptor.defaultSelection
        )
    }

    func setLegacyCodable(
        _ value: Payload,
        for source: MHLegacyStorageReference,
        in userDefaults: UserDefaults
    ) {
        let sourceDescriptor = MHCodablePreferenceDescriptor<Payload>(
            storageKey: source.storageKey,
            defaultSelection: source.selection
        )
        MHPreferenceStore(userDefaults: userDefaults).setCodable(
            value,
            for: sourceDescriptor
        )
    }
}
#endif
