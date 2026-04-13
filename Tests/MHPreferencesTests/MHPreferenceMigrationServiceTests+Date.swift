#if canImport(Foundation)
import Foundation
import MHPreferences
import Testing

extension MHPreferenceMigrationServiceTests {
    @Test
    func move_date_preserves_value_and_removes_source() async throws {
        let oldSuiteName = "MHPreferenceMigrationServiceTests.date-old.\(UUID().uuidString)"
        let newSuiteName = "MHPreferenceMigrationServiceTests.date-new.\(UUID().uuidString)"
        let oldDefaults = try makeUserDefaults(suiteName: oldSuiteName)
        let newDefaults = try makeUserDefaults(suiteName: newSuiteName)
        defer {
            oldDefaults.removePersistentDomain(forName: oldSuiteName)
            newDefaults.removePersistentDomain(forName: newSuiteName)
        }

        let legacySource = MHLegacyStorageReference(
            storageKey: "\(Constants.storageKeyPrefix).date-legacy",
            selection: .suite(oldSuiteName)
        )
        let target = makeDateDescriptor(
            "date-current",
            defaultSelection: .suite(newSuiteName),
            legacySources: [legacySource]
        )
        let steps = target.migrationSteps()
        let migratedDateReferenceInterval = 8.0
        let migratedDateValue = Date(
            timeIntervalSinceReferenceDate: migratedDateReferenceInterval
        )

        oldDefaults.set(
            migratedDateValue,
            forKey: legacySource.storageKey
        )

        let outcome = await MHPreferenceMigrationService.run(
            steps: steps,
            stateDescriptor: makeStateDescriptor(
                "date-state",
                defaultSelection: MHUserDefaultsSelection.suite(newSuiteName)
            )
        )

        #expect(oldDefaults.object(forKey: legacySource.storageKey) == nil)
        #expect(
            MHPreferenceStore(userDefaults: newDefaults).date(for: target)
                == migratedDateValue
        )

        assertSucceeded(
            outcome,
            completedStepIDs: steps.map(\MHPreferenceMigrationStep.id),
            skippedStepIDs: []
        )
    }

    func makeDateDescriptor(
        _ name: String,
        defaultSelection: MHUserDefaultsSelection,
        legacySources: [MHLegacyStorageReference] = []
    ) -> MHDatePreferenceDescriptor {
        .init(
            storageKey: "\(Constants.storageKeyPrefix).\(name)",
            defaultSelection: defaultSelection,
            legacySources: legacySources
        )
    }
}
#endif
