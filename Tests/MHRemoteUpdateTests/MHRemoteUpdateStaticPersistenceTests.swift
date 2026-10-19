import Foundation
import MHRemoteUpdate
import Synchronization
import Testing

struct MHRemoteUpdateStaticPersistenceTests: Sendable {
    private typealias Fixture = StaticPolicyTestSupport

    @Test
    func restoringRepeatedlyDoesNotExtendTheLastSuccessfulFetch() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        let store = MHRemoteUpdateStore(fileURL: directory.appendingPathComponent("policy.json"))
        let clock = Fixture.Clock()
        let policy = try makePolicy()
        let updates = try makeController(clock: clock, store: store) { policy }
        try await updates.refresh()
        for day in [10.0, 20, 30, 31] {
            clock.set(day: day)
            let restored = try makeController(clock: clock, store: store) { throw Fixture.Failure.offline }
            let result = try await restored.prepare()
            #expect(result.restorationError == nil)
            #expect(result.refreshError is Fixture.Failure)
            #expect(result.decision == (day < 30 ? .notRequired : .unavailable))
            try await restored.restore()
            #expect(await restored.decision() == result.decision)
        }
        #expect(try await updates.refresh() == .notRequired)
        clock.set(day: 60)
        let renewed = try makeController(clock: clock, store: store) { throw Fixture.Failure.offline }
        try await renewed.restore()
        #expect(await renewed.decision() == .notRequired)
        clock.set(day: 61)
        #expect(await renewed.decision() == .unavailable)
    }

    @Test
    func legacySnapshotRetainsItsExpiryAndMigratesOnlyAfterAHigherStaticRevision() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        let store = MHRemoteUpdateStore(fileURL: directory.appendingPathComponent("policy.json"))
        let bounded = try MHRemoteUpdateSchedule(
            bundleIdentifier: "example.app",
            revision: 1,
            issuedAt: Fixture.date(0),
            validUntil: Fixture.date(2),
            requirement: nil
        )
        try store.save(.init(schedule: bounded, storefront: "jp", publication: nil))
        #expect(try store.load()?.schedule == bounded)
        let clock = Fixture.Clock()
        let policy = Mutex(try makePolicy())
        let updates = try makeController(clock: clock, store: store) { policy.withLock { $0 } }
        try await updates.restore()
        #expect(await updates.decision() == .notRequired)
        clock.set(day: 2)
        #expect(await updates.decision() == .unavailable)
        await #expect(throws: MHRemoteUpdateController.Failure.revisionConflict) {
            try await updates.refresh()
        }
        let migrated = try makePolicy(revision: 2)
        policy.withLock { $0 = migrated }
        #expect(try await updates.refresh() == .notRequired)
        let restarted = try makeController(clock: clock, store: store) { throw Fixture.Failure.offline }
        try await restarted.restore()
        #expect(await restarted.decision() == .notRequired)
        clock.set(day: 32)
        #expect(await restarted.decision() == .unavailable)
    }

    @Test
    func retainedFutureRequirementAndPublicationAreReevaluatedAfterRestart() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        let store = MHRemoteUpdateStore(fileURL: directory.appendingPathComponent("policy.json"))
        let clock = Fixture.Clock()
        let policy = try makePolicy(minimum: "2", activationDay: 0.5)
        let updates = try makeController(clock: clock, store: store) { policy }
        #expect(try await updates.refresh() == .notRequired)
        clock.set(day: 0.5)
        let restored = try makeController(clock: clock, store: store) { throw Fixture.Failure.offline }
        try await restored.restore()
        #expect(await restored.decision() == .updateRequired)
        clock.set(day: 1)
        #expect(await restored.decision() == .unavailable)
    }

    @Test
    func saveFailureRejectsTheOperationBeforeMutationAndSuccessEffects() async throws {
        let blocked = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try Data("not a directory".utf8).write(to: blocked)
        defer {
            try? FileManager.default.removeItem(at: blocked)
        }
        let store = MHRemoteUpdateStore(fileURL: blocked.appendingPathComponent("policy.json"))
        let clock = Fixture.Clock()
        let policy = try makePolicy()
        let updates = try makeController(clock: clock, store: store) { policy }
        await #expect(throws: (any Error).self) {
            try await updates.checkOperationAllowed()
            Issue.record("Mutation and success effects must not start after a save failure")
        }
        #expect(await updates.decision() == .notRequired)
    }

    @Test
    func restoredPolicyRespectsAShorterLocalLifetime() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        let store = MHRemoteUpdateStore(fileURL: directory.appendingPathComponent("policy.json"))
        let clock = Fixture.Clock()
        let policy = try makePolicy()
        let updates = try makeController(clock: clock, store: store) { policy }
        try await updates.refresh()
        clock.set(day: 2)
        let shorter = try makeController(clock: clock, store: store, policyDays: 1) { policy }
        try await shorter.restore()
        #expect(await shorter.decision() == .unavailable)
    }

    private func makePolicy(
        revision: Int = 1,
        minimum: String? = nil,
        activationDay: Double = 0,
        endDay: Double? = nil
    ) throws -> MHRemoteUpdateStaticPolicy {
        let requirement = try minimum.map { minimum in
            try MHRemoteUpdateSchedule.Requirement(
                minimumVersion: #require(MHAppVersion(minimum)),
                effectiveAt: Fixture.date(activationDay),
                endsAt: endDay.map(Fixture.date)
            )
        }
        return try .init(bundleIdentifier: "example.app", revision: revision, requirement: requirement)
    }

    private func makeController(
        clock: Fixture.Clock,
        store: MHRemoteUpdateStore? = nil,
        installedVersion: String = "1",
        policyDays: Double = 30,
        publicationDays: Double = 1,
        fetch: @escaping @Sendable () async throws -> MHRemoteUpdateStaticPolicy,
        publicVersion: @escaping @Sendable () async throws -> MHAppVersion? = { MHAppVersion("2") }
    ) throws -> MHRemoteUpdateController {
        try .init(
            bundleIdentifier: "example.app",
            storefront: "jp",
            policyLifetime: policyDays * Fixture.day,
            publicationLifetime: publicationDays * Fixture.day,
            store: store,
            currentVersion: { installedVersion },
            now: { clock.now() },
            fetchPolicy: fetch,
            publicVersion: publicVersion
        )
    }
}
