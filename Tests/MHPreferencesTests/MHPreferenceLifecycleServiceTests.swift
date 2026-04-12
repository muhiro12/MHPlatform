#if canImport(Foundation)
import Foundation
import MHPreferences
import Testing

struct MHPreferenceLifecycleServiceTests {}

private extension MHPreferenceLifecycleServiceTests {
    enum Constants {
        static let storageKeyPrefix = "tests.preference-lifecycle"
        static let expectedCleanupDomainCount = 2
    }

    struct LifecycleScenario {
        let legacySuiteName: String
        let currentSuiteName: String
        let legacyDefaults: UserDefaults
        let currentDefaults: UserDefaults
        let displayNameDescriptor: MHStringPreferenceDescriptor
        let notificationsDescriptor: MHBoolPreferenceDescriptor
        let migrationStateDescriptor: MHPreferenceMigrationStateDescriptor

        var descriptors: [any MHStorageDescriptorProtocol] {
            [
                displayNameDescriptor,
                notificationsDescriptor
            ]
        }
    }
}

extension MHPreferenceLifecycleServiceTests {
    @Test
    func run_migrates_legacy_sources_and_cleans_touched_domains() async throws {
        let scenario = try makeLifecycleScenario()
        defer {
            scenario.legacyDefaults.removePersistentDomain(
                forName: scenario.legacySuiteName
            )
            scenario.currentDefaults.removePersistentDomain(
                forName: scenario.currentSuiteName
            )
        }

        seedLifecycleScenario(scenario)

        let outcome = await MHPreferenceLifecycleService.run(
            descriptors: scenario.descriptors,
            migrationStateDescriptor: scenario.migrationStateDescriptor
        )

        assertLifecycleScenarioMigrated(
            scenario,
            outcome: outcome
        )

        assertSucceeded(
            outcome.migrationOutcome,
            completedStepIDs: scenario.displayNameDescriptor.migrationSteps()
                .map(\.id),
            skippedStepIDs: []
        )
    }

    @Test
    func run_accepts_concrete_descriptor_sequences() async throws {
        let legacySuiteName = "MHPreferenceLifecycleServiceTests.generic-legacy.\(UUID().uuidString)"
        let currentSuiteName = "MHPreferenceLifecycleServiceTests.generic-current.\(UUID().uuidString)"
        let legacyDefaults = try makeUserDefaults(suiteName: legacySuiteName)
        let currentDefaults = try makeUserDefaults(suiteName: currentSuiteName)
        defer {
            legacyDefaults.removePersistentDomain(forName: legacySuiteName)
            currentDefaults.removePersistentDomain(forName: currentSuiteName)
        }

        let descriptor = MHStringPreferenceDescriptor(
            storageKey: "\(Constants.storageKeyPrefix).generic-display-name",
            defaultSelection: .suite(currentSuiteName),
            legacySources: [
                .init(
                    storageKey: "\(Constants.storageKeyPrefix).generic-legacy-display-name",
                    selection: .suite(legacySuiteName)
                )
            ]
        )
        let migrationStateDescriptor = MHPreferenceMigrationStateDescriptor(
            storageKey: "\(Constants.storageKeyPrefix).generic-migration-state",
            defaultSelection: .suite(currentSuiteName)
        )

        legacyDefaults.set(
            "Avery",
            forKey: "\(Constants.storageKeyPrefix).generic-legacy-display-name"
        )

        let outcome = await MHPreferenceLifecycleService.run(
            descriptors: [descriptor],
            migrationStateDescriptor: migrationStateDescriptor
        )

        #expect(
            currentDefaults.string(forKey: descriptor.storageKey)
                == "Avery"
        )
        assertSucceeded(
            outcome.migrationOutcome,
            completedStepIDs: descriptor.migrationSteps().map(\.id),
            skippedStepIDs: []
        )
    }
}

private extension MHPreferenceLifecycleServiceTests {
    func makeLifecycleScenario() throws -> LifecycleScenario {
        let legacySuiteName = "MHPreferenceLifecycleServiceTests.legacy.\(UUID().uuidString)"
        let currentSuiteName = "MHPreferenceLifecycleServiceTests.current.\(UUID().uuidString)"

        return .init(
            legacySuiteName: legacySuiteName,
            currentSuiteName: currentSuiteName,
            legacyDefaults: try makeUserDefaults(suiteName: legacySuiteName),
            currentDefaults: try makeUserDefaults(suiteName: currentSuiteName),
            displayNameDescriptor: .init(
                storageKey: "\(Constants.storageKeyPrefix).display-name",
                defaultSelection: .suite(currentSuiteName),
                legacySources: [
                    .init(
                        storageKey: "\(Constants.storageKeyPrefix).legacy-display-name",
                        selection: .suite(legacySuiteName)
                    )
                ]
            ),
            notificationsDescriptor: .init(
                storageKey: "\(Constants.storageKeyPrefix).notifications",
                defaultSelection: .suite(currentSuiteName),
                default: true
            ),
            migrationStateDescriptor: .init(
                storageKey: "\(Constants.storageKeyPrefix).migration-state",
                defaultSelection: .suite(currentSuiteName)
            )
        )
    }

    func seedLifecycleScenario(
        _ scenario: LifecycleScenario
    ) {
        scenario.legacyDefaults.set(
            "Taylor",
            forKey: "\(Constants.storageKeyPrefix).legacy-display-name"
        )
        scenario.legacyDefaults.set(
            "stale",
            forKey: "\(Constants.storageKeyPrefix).legacy-unknown"
        )
        scenario.currentDefaults.set(
            false,
            forKey: scenario.notificationsDescriptor.storageKey
        )
        scenario.currentDefaults.set(
            "stale",
            forKey: "\(Constants.storageKeyPrefix).current-unknown"
        )
    }

    func assertLifecycleScenarioMigrated(
        _ scenario: LifecycleScenario,
        outcome: MHPreferenceLifecycleOutcome
    ) {
        #expect(
            scenario.legacyDefaults.object(
                forKey: "\(Constants.storageKeyPrefix).legacy-display-name"
            ) == nil
        )
        #expect(
            scenario.legacyDefaults.object(
                forKey: "\(Constants.storageKeyPrefix).legacy-unknown"
            ) == nil
        )
        #expect(
            scenario.currentDefaults.string(
                forKey: scenario.displayNameDescriptor.storageKey
            ) == "Taylor"
        )
        #expect(
            scenario.currentDefaults.bool(
                forKey: scenario.notificationsDescriptor.storageKey
            ) == false
        )
        #expect(
            scenario.currentDefaults.object(
                forKey: "\(Constants.storageKeyPrefix).current-unknown"
            ) == nil
        )
        #expect(
            scenario.currentDefaults.object(
                forKey: scenario.migrationStateDescriptor.storageKey
            ) is Data
        )

        let cleanupReportsByDomain = Dictionary(
            uniqueKeysWithValues: outcome.cleanupReports.map { report in
                (report.domainName, report.report.removedStorageKeys)
            }
        )
        #expect(
            cleanupReportsByDomain.count
                == Constants.expectedCleanupDomainCount
        )
        #expect(
            cleanupReportsByDomain[scenario.legacySuiteName]
                == ["\(Constants.storageKeyPrefix).legacy-unknown"]
        )
        #expect(
            cleanupReportsByDomain[scenario.currentSuiteName]
                == ["\(Constants.storageKeyPrefix).current-unknown"]
        )
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
}
#endif
