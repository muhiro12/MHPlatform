import Foundation
import MHPreferences
import Testing

struct MHPreferenceRegistryTests {
    private struct CustomDescriptor: MHStorageDescriptorProtocol {
        let storageKey: String
        let defaultSelection: MHUserDefaultsSelection
        let steps: [MHPreferenceMigrationStep]

        func migrationSteps(store _: MHPreferenceStore) -> [MHPreferenceMigrationStep] {
            steps
        }
    }

    private enum TestError: Error {
        case rejected
    }

    @Test
    func synchronous_registry_migrates_before_return_and_async_run_skips_completed_steps() async throws {
        let suiteName = "tests.registry.sync.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }
        let descriptor = MHStringPreferenceDescriptor(
            storageKey: "current",
            defaultSelection: .suite(suiteName),
            legacySources: [.init(storageKey: "legacy", selection: .suite(suiteName))]
        )
        let state = MHPreferenceMigrationStateDescriptor(
            storageKey: "state",
            defaultSelection: .suite(suiteName)
        )
        let registry = MHPreferenceRegistry(descriptors: [descriptor], migrationStateDescriptor: state)
        defaults.set("Avery", forKey: "legacy")
        defaults.set("remove", forKey: "unknown")

        let firstOutcome = registry.runSynchronously()

        #expect(defaults.string(forKey: "current") == "Avery")
        #expect(defaults.object(forKey: "legacy") == nil)
        #expect(defaults.object(forKey: "unknown") == nil)
        #expect(firstOutcome.cleanupReports.first?.report.knownStorageKeys == ["current", "state"])
        guard case let .succeeded(completed, skipped) = firstOutcome.migrationOutcome else {
            Issue.record("Expected synchronous migration to succeed")
            return
        }
        #expect(completed == descriptor.migrationSteps().map(\.id))
        #expect(skipped.isEmpty)

        let secondOutcome = await registry.run()
        guard case let .succeeded(secondCompleted, secondSkipped) = secondOutcome.migrationOutcome else {
            Issue.record("Expected asynchronous rerun to succeed")
            return
        }
        #expect(secondCompleted.isEmpty)
        #expect(secondSkipped == completed)
        #expect(defaults.string(forKey: "current") == "Avery")
    }

    @Test
    func async_only_step_rejects_whole_sync_plan_without_migration_or_cleanup() throws {
        let suiteName = "tests.registry.async-only.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }
        let store = MHPreferenceStore(selection: .suite(suiteName))
        let target = MHBoolPreferenceDescriptor(storageKey: "changed", defaultSelection: .suite(suiteName))
        let descriptor = CustomDescriptor(
            storageKey: "custom",
            defaultSelection: .suite(suiteName),
            steps: [
                .synchronous(id: "first") {
                    store.set(true, for: target)
                },
                .init(id: "async-only") {
                    await Task.yield()
                }
            ]
        )
        let registry = MHPreferenceRegistry(
            descriptors: [descriptor],
            migrationStateDescriptor: .init(storageKey: "state", defaultSelection: .suite(suiteName))
        )
        defaults.set("preserve", forKey: "unknown")

        let outcome = registry.runSynchronously()

        #expect(outcome.cleanupReports.isEmpty)
        #expect(defaults.string(forKey: "unknown") == "preserve")
        #expect(defaults.object(forKey: "changed") == nil)
        #expect(defaults.object(forKey: "state") == nil)
        guard case let .failed(error, failedID, completed, skipped) = outcome.migrationOutcome else {
            Issue.record("Expected async-only preflight failure")
            return
        }
        #expect(error as? MHPreferenceSynchronousMigrationError == .asynchronousStep(id: "async-only"))
        #expect(failedID == "async-only")
        #expect(completed.isEmpty)
        #expect(skipped.isEmpty)
    }

    @Test
    func synchronous_failure_keeps_cleanup_data_and_records_only_successful_steps() throws {
        let suiteName = "tests.registry.failure.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }
        let descriptor = CustomDescriptor(
            storageKey: "custom",
            defaultSelection: .suite(suiteName),
            steps: [
                .synchronous(id: "first") {
                    // Record a successful step before the following failure.
                },
                .synchronous(id: "failure") {
                    throw TestError.rejected
                },
                .synchronous(id: "last") {
                    Issue.record("Steps after a failure must not run")
                }
            ]
        )
        let registry = MHPreferenceRegistry(
            descriptors: [descriptor],
            migrationStateDescriptor: .init(storageKey: "state", defaultSelection: .suite(suiteName))
        )
        defaults.set("preserve", forKey: "unknown")

        let outcome = registry.runSynchronously()

        #expect(outcome.cleanupReports.isEmpty)
        #expect(defaults.string(forKey: "unknown") == "preserve")
        let data = try #require(defaults.data(forKey: "state"))
        #expect(try JSONDecoder().decode([String].self, from: data) == ["first"])
        guard case let .failed(_, failedID, completed, _) = outcome.migrationOutcome else {
            Issue.record("Expected synchronous action failure")
            return
        }
        #expect(failedID == "failure")
        #expect(completed == ["first"])
    }

    @Test
    func synchronous_run_skips_async_steps_already_completed_by_async_runner() async throws {
        let suiteName = "tests.registry.completed.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }
        let steps = [MHPreferenceMigrationStep(id: "async-only") {
            await Task.yield()
        }]
        let state = MHPreferenceMigrationStateDescriptor(storageKey: "state", defaultSelection: .suite(suiteName))
        _ = await MHPreferenceMigrationService.run(steps: steps, stateDescriptor: state)

        let outcome = MHPreferenceMigrationService.runSynchronously(steps: steps, stateDescriptor: state)

        guard case let .succeeded(completed, skipped) = outcome else {
            Issue.record("Completed async steps must remain skippable")
            return
        }
        #expect(completed.isEmpty)
        #expect(skipped == ["async-only"])
    }
}
