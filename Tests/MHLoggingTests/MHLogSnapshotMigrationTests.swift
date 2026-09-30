import Foundation
import MHLogging
import MHPreferences
import Testing

@MainActor
struct MHLogSnapshotMigrationTests {
    private struct HistoricalSnapshot: Codable {
        let sessionIdentifier: UUID
        let events: [MHLogEvent]
    }

    private struct Fixture {
        let sourceDomain = "tests.log-migration.source.\(UUID())"
        let targetDomain = "tests.log-migration.target.\(UUID())"

        var source: MHLegacyStorageReference {
            .init(storageKey: "legacy", selection: .suite(sourceDomain))
        }

        var destination: MHLogSnapshotStorageDescriptors {
            .init(
                current: .init(storageKey: "current", defaultSelection: .suite(targetDomain)),
                previous: .init(storageKey: "previous", defaultSelection: .suite(targetDomain))
            )
        }

        var state: MHPreferenceMigrationStateDescriptor {
            .init(storageKey: "state", defaultSelection: .suite(targetDomain))
        }

        var store: MHPreferenceStore {
            .init()
        }

        var step: MHPreferenceMigrationStep {
            MHLogSnapshotMigration.step(id: "legacy-logs", from: source, to: destination)
        }

        func run() -> MHPreferenceMigrationOutcome {
            MHPreferenceMigrationService.runSynchronously(steps: [step], stateDescriptor: state)
        }

        func clear() {
            UserDefaults(suiteName: sourceDomain)?.removePersistentDomain(forName: sourceDomain)
            UserDefaults(suiteName: targetDomain)?.removePersistentDomain(forName: targetDomain)
        }
    }

    @Test(arguments: [false, true])
    func legacy_formats_are_readable_as_previous_session_after_migration(envelope: Bool) async throws {
        let fixture = Fixture()
        defer {
            fixture.clear()
        }
        let events = [MHLogEvent(
            level: .warning,
            subsystem: "tests",
            category: "Migration",
            message: "retained",
            source: .init(file: "fixture.swift", function: "legacy", line: 1),
            timestamp: .init(timeIntervalSince1970: 1)
        )]
        let data: Data
        if envelope {
            data = try JSONEncoder().encode(HistoricalSnapshot(sessionIdentifier: UUID(), events: events))
        } else {
            data = try JSONEncoder().encode(events)
        }
        let defaults = try #require(UserDefaults(suiteName: fixture.sourceDomain))
        defaults.set(data, forKey: fixture.source.storageKey)

        guard case .succeeded = fixture.run() else {
            Issue.record("Legacy snapshot must migrate")
            return
        }
        #expect(defaults.object(forKey: fixture.source.storageKey) == nil)
        let bootstrap = MHLoggingBootstrap(snapshotStorageDescriptors: fixture.destination)
        #expect(bootstrap.hasPreviousSession)
        #expect(await bootstrap.events(in: .previous) == events)
        #expect(await bootstrap.events(in: .current).isEmpty)

        // A completed step must not consume a newly written legacy slot.
        defaults.set(data, forKey: fixture.source.storageKey)
        guard case let .succeeded(completed, skipped) = fixture.run() else {
            Issue.record("Completed migration must be skipped")
            return
        }
        #expect(completed.isEmpty)
        #expect(skipped == ["legacy-logs"])
        #expect(defaults.data(forKey: fixture.source.storageKey) == data)
    }

    @Test(arguments: [false, true])
    func occupied_destination_retains_both_slots_and_legacy_data(current: Bool) throws {
        let fixture = Fixture()
        defer {
            fixture.clear()
        }
        let defaults = try #require(UserDefaults(suiteName: fixture.sourceDomain))
        let targetDefaults = try #require(UserDefaults(suiteName: fixture.targetDomain))
        let data = try JSONEncoder().encode([MHLogEvent]())
        defaults.set(data, forKey: fixture.source.storageKey)
        let occupiedKey = current ? fixture.destination.current.storageKey : fixture.destination.previous.storageKey
        targetDefaults.set("existing", forKey: occupiedKey)

        guard case let .failed(error, _, completed, _) = fixture.run() else {
            Issue.record("Destination conflicts must fail")
            return
        }
        #expect(error as? MHLogSnapshotMigration.MigrationError == .destinationOccupied)
        #expect(completed.isEmpty)
        #expect(defaults.data(forKey: fixture.source.storageKey) == data)
        #expect(targetDefaults.string(forKey: occupiedKey) == "existing")
        #expect(targetDefaults.object(forKey: fixture.state.storageKey) == nil)
    }

    @Test
    func malformed_source_is_retained_without_completion() throws {
        let fixture = Fixture()
        defer {
            fixture.clear()
        }
        let defaults = try #require(UserDefaults(suiteName: fixture.sourceDomain))
        let data = Data("invalid JSON".utf8)
        defaults.set(data, forKey: fixture.source.storageKey)

        guard case .failed = fixture.run() else {
            Issue.record("Malformed source must fail")
            return
        }
        #expect(defaults.data(forKey: fixture.source.storageKey) == data)
        #expect(fixture.store.contains(fixture.destination.current) == false)
        #expect(fixture.store.contains(fixture.destination.previous) == false)
        #expect(fixture.store.contains(fixture.state) == false)
    }

    @Test
    func missing_source_does_not_create_snapshots() {
        let fixture = Fixture()
        defer {
            fixture.clear()
        }
        guard case .succeeded = fixture.run() else {
            Issue.record("Missing legacy source is a no-op")
            return
        }
        #expect(fixture.store.contains(fixture.destination.current) == false)
        #expect(fixture.store.contains(fixture.destination.previous) == false)
    }
}
