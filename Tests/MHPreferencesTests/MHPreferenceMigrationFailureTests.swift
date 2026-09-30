import Foundation
import MHPreferences
import Testing

struct MHPreferenceMigrationFailureTests {
    private enum Failure: Error {
        case encoding
    }

    private final class FailingEncoder: JSONEncoder, @unchecked Sendable {
        override func encode<Value: Encodable>(_: Value) throws -> Data {
            throw Failure.encoding
        }
    }

    @Test(arguments: [false, true])
    func malformed_legacy_codable_stops_migration_and_cleanup(synchronous: Bool) async throws {
        let suiteName = "tests.migration.corrupt.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }
        let data = Data("invalid JSON".utf8)
        defaults.set(data, forKey: "legacy")
        defaults.set("keep", forKey: "unknown")
        let registry = MHPreferenceRegistry(
            descriptors: [MHCodablePreferenceDescriptor<[String]>(
                storageKey: "current",
                defaultSelection: .suite(suiteName),
                legacySources: [.init(storageKey: "legacy", selection: .suite(suiteName))]
            )],
            migrationStateDescriptor: .init(storageKey: "state", defaultSelection: .suite(suiteName))
        )
        let outcome: MHPreferenceLifecycleOutcome
        if synchronous {
            outcome = registry.runSynchronously()
        } else {
            outcome = await registry.run()
        }

        guard case .failed = outcome.migrationOutcome else {
            Issue.record("Undecodable legacy data must fail migration")
            return
        }
        #expect(outcome.cleanupReports.isEmpty)
        #expect(defaults.data(forKey: "legacy") == data)
        #expect(defaults.string(forKey: "unknown") == "keep")
        #expect(defaults.object(forKey: "current") == nil)
        #expect(defaults.object(forKey: "state") == nil)
    }

    @Test(arguments: [false, true])
    func malformed_completion_state_preserves_all_data(synchronous: Bool) async throws {
        let suiteName = "tests.migration.state.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }
        defaults.set("invalid state", forKey: "state")
        defaults.set(true, forKey: "legacy")
        let registry = MHPreferenceRegistry(
            descriptors: [MHBoolPreferenceDescriptor(
                storageKey: "current",
                defaultSelection: .suite(suiteName),
                legacySources: [.init(storageKey: "legacy", selection: .suite(suiteName))]
            )],
            migrationStateDescriptor: .init(storageKey: "state", defaultSelection: .suite(suiteName))
        )
        let outcome: MHPreferenceLifecycleOutcome
        if synchronous {
            outcome = registry.runSynchronously()
        } else {
            outcome = await registry.run()
        }

        guard case let .failed(_, failedID, _, _) = outcome.migrationOutcome else {
            Issue.record("Unreadable completion state must fail before any step")
            return
        }
        #expect(failedID == "state")
        #expect(outcome.cleanupReports.isEmpty)
        #expect(defaults.bool(forKey: "legacy"))
        #expect(defaults.object(forKey: "current") == nil)
        #expect(defaults.string(forKey: "state") == "invalid state")
    }

    @Test(arguments: [false, true])
    func encoding_failure_preserves_legacy_and_does_not_complete_step(synchronous: Bool) async throws {
        let suiteName = "tests.migration.encoding.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }
        let data = try JSONEncoder().encode(["keep"])
        defaults.set(data, forKey: "legacy")
        let step = MHPreferenceMigrationStep.move(
            id: "move",
            from: .init(storageKey: "legacy", selection: .suite(suiteName)),
            to: MHCodablePreferenceDescriptor<[String]>(storageKey: "current", defaultSelection: .suite(suiteName)),
            store: .init(encoder: FailingEncoder())
        )
        let state = MHPreferenceMigrationStateDescriptor(storageKey: "state", defaultSelection: .suite(suiteName))
        let outcome: MHPreferenceMigrationOutcome
        if synchronous {
            outcome = MHPreferenceMigrationService.runSynchronously(steps: [step], stateDescriptor: state)
        } else {
            outcome = await MHPreferenceMigrationService.run(steps: [step], stateDescriptor: state)
        }

        guard case let .failed(_, failedID, completed, _) = outcome else {
            Issue.record("Encoding failure must fail the move")
            return
        }
        #expect(failedID == "move")
        #expect(completed.isEmpty)
        #expect(defaults.data(forKey: "legacy") == data)
        #expect(defaults.object(forKey: "current") == nil)
        #expect(defaults.object(forKey: "state") == nil)
    }
    @Test(arguments: [false, true])
    func completion_write_failure_is_reported_without_cleanup(synchronous: Bool) async throws {
        let suiteName = "tests.migration.completion.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }
        defaults.set(true, forKey: "legacy")
        defaults.set("keep", forKey: "unknown")
        let registry = MHPreferenceRegistry(
            descriptors: [MHBoolPreferenceDescriptor(
                storageKey: "current",
                defaultSelection: .suite(suiteName),
                legacySources: [.init(storageKey: "legacy", selection: .suite(suiteName))]
            )],
            migrationStateDescriptor: .init(storageKey: "state", defaultSelection: .suite(suiteName))
        )
        let stateStore = MHPreferenceStore(encoder: FailingEncoder())
        let outcome: MHPreferenceLifecycleOutcome
        if synchronous {
            outcome = registry.runSynchronously(stateStore: stateStore)
        } else {
            outcome = await registry.run(stateStore: stateStore)
        }

        guard case let .failed(_, _, completed, _) = outcome.migrationOutcome else {
            Issue.record("Completion encoding failure must stop lifecycle work")
            return
        }
        #expect(completed.isEmpty)
        #expect(outcome.cleanupReports.isEmpty)
        #expect(defaults.bool(forKey: "current"))
        #expect(defaults.object(forKey: "state") == nil)
        #expect(defaults.string(forKey: "unknown") == "keep")
    }
}
