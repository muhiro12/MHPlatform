import Foundation
import MHRemoteUpdate
import Testing

struct MHRemoteUpdatePersistenceTests: Sendable {
    private typealias Fixture = RemoteUpdateTestSupport

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
    ) throws -> MHRemoteUpdateSchedule {
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
        fetch: @escaping @Sendable () async throws -> MHRemoteUpdateSchedule,
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
            fetchSchedule: {
                .init(value: try await fetch(), fetchedAt: clock.now())
            },
            publicVersion: publicVersion
        )
    }
}
