import Foundation
import MHRemoteUpdate
import Testing

struct MHRemoteUpdateSharedStoreTests {
    private actor PublicationGate {
        private var continuation: CheckedContinuation<MHAppVersion?, Never>?

        var hasRequest: Bool { continuation != nil }

        func fetch() async -> MHAppVersion? {
            await withCheckedContinuation { continuation in
                self.continuation = continuation
            }
        }

        func complete() {
            continuation?.resume(returning: MHAppVersion("2"))
            continuation = nil
        }
    }
    private enum Instant {
        static let earlier = Date(timeIntervalSinceReferenceDate: 10)
        static let later = Date(timeIntervalSinceReferenceDate: 20)
        static let expiry = Date(timeIntervalSinceReferenceDate: 100)
    }

    @Test
    func staleOwnerCannotOverwriteNewerPolicyAndObservesItBeforeAnOperation() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        let store = MHRemoteUpdateStore(fileURL: directory.appendingPathComponent("policy.json"))
        let initial = try snapshot(revision: 1, minimum: nil, fetchedAt: Instant.earlier)
        try store.save(initial)
        let stale = try controller(store: store, schedule: initial.schedule)
        let observer = try controller(store: store, schedule: initial.schedule)
        try await stale.restore()
        try await observer.restore()
        let required = try snapshot(revision: 2, minimum: "2", fetchedAt: Instant.later)
        try store.save(required)
        await #expect(throws: MHRemoteUpdateController.Failure.revisionConflict) {
            try await stale.refresh()
        }
        #expect(try store.load() == required)
        #expect(await stale.evaluation().revision == 2)
        await #expect(throws: MHRemoteUpdateOperationError.updateRequired) {
            try await observer.checkOperationAllowed(for: .allowWhenUnavailable)
        }
        #expect(await observer.evaluation().revision == 2)
    }

    @Test
    func coordinatedWritersPreserveTheHighestRevision() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        let store = MHRemoteUpdateStore(fileURL: directory.appendingPathComponent("policy.json"))
        let snapshots = try (1...20).map { revision in
            try snapshot(revision: revision, minimum: nil, fetchedAt: Instant.earlier)
        }
        await withTaskGroup(of: Void.self) { group in
            for value in snapshots {
                group.addTask {
                    do {
                        try store.save(value)
                    } catch MHRemoteUpdateController.Failure.revisionConflict {
                        // A newer coordinated writer has already committed its policy.
                    } catch {
                        Issue.record(error)
                    }
                }
            }
        }
        #expect(try store.load()?.schedule.revision == 20)
    }

    @Test
    func equalRevisionMergesFreshnessWithoutRenewingOlderEvidence() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        let store = MHRemoteUpdateStore(fileURL: directory.appendingPathComponent("policy.json"))
        let older = try snapshot(revision: 1, minimum: "2", fetchedAt: Instant.earlier)
        let newer = try snapshot(revision: 1, minimum: "2", fetchedAt: Instant.later)
        try store.save(newer)
        try store.save(older)
        #expect(try store.load() == newer)
        #expect(throws: MHRemoteUpdateController.Failure.revisionConflict) {
            try store.save(snapshot(revision: 1, minimum: nil, fetchedAt: Instant.later))
        }
        #expect(try store.load() == newer)
    }

    @Test
    func stalePositivePublicationCannotUndoANewerEmptyLookup() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        let store = MHRemoteUpdateStore(fileURL: directory.appendingPathComponent("policy.json"))
        let original = try snapshot(revision: 1, minimum: "2", fetchedAt: Instant.earlier)
        try store.save(original)
        let updates = try controller(store: store, schedule: original.schedule, published: nil)
        try await updates.restore()
        #expect(try await updates.refresh() == .unavailable)
        #expect(try store.load()?.publication == nil)
        try store.save(original)
        #expect(try store.load()?.publication == nil)
        let restarted = try controller(store: store, schedule: original.schedule)
        try await restarted.restore()
        #expect(await restarted.decision() == .unavailable)
    }

    @Test(.timeLimit(.minutes(1)))
    func latePublicationCannotRollBackNewerMemoryEvenWhenTheStoreBecomesUnwritable() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        let store = MHRemoteUpdateStore(fileURL: directory.appendingPathComponent("policy.json"))
        let original = try snapshot(revision: 1, minimum: "2", fetchedAt: Instant.earlier)
        let gate = PublicationGate()
        let updates = try MHRemoteUpdateController(
            bundleIdentifier: "example.app",
            storefront: nil,
            policyLifetime: 100,
            publicationLifetime: 100,
            store: store,
            currentVersion: { "1" },
            now: { Instant.later },
            fetchSchedule: { .init(value: original.schedule, fetchedAt: Instant.earlier) },
            publicVersion: { await gate.fetch() }
        )
        let refresh = Task { try await updates.refresh() }
        while await gate.hasRequest == false {
            await Task.yield()
        }
        let newer = try snapshot(revision: 2, minimum: "3", fetchedAt: Instant.later)
        try store.save(newer)
        try await updates.restore()
        try FileManager.default.removeItem(at: directory)
        try Data("not a directory".utf8).write(to: directory)
        await gate.complete()
        await #expect(throws: MHRemoteUpdateController.Failure.revisionConflict) {
            try await refresh.value
        }
        #expect(await updates.evaluation().revision == 2)
        #expect(await updates.evaluation().minimumVersion == MHAppVersion("3"))
    }

    private func snapshot(revision: Int, minimum: String?, fetchedAt: Date) throws -> MHRemoteUpdateSnapshot {
        let requirement = try minimum.map { value in
            try MHRemoteUpdateSchedule.Requirement(
                minimumVersion: #require(MHAppVersion(value)), effectiveAt: Instant.earlier
            )
        }
        return try .init(
            schedule: .init(bundleIdentifier: "example.app", revision: revision, requirement: requirement),
            storefront: nil,
            observation: .init(fetchedAt: fetchedAt, validUntil: Instant.expiry),
            publication: .init(
                version: #require(MHAppVersion("2")), checkedAt: fetchedAt, validUntil: Instant.expiry
            )
        )
    }

    private func controller(
        store: MHRemoteUpdateStore,
        schedule: MHRemoteUpdateSchedule,
        published: String? = "2"
    ) throws -> MHRemoteUpdateController {
        try .init(
            bundleIdentifier: "example.app",
            storefront: nil,
            policyLifetime: 100,
            publicationLifetime: 100,
            store: store,
            currentVersion: { "1" },
            now: { Instant.later },
            fetchSchedule: { .init(value: schedule, fetchedAt: Instant.earlier) },
            publicVersion: { published.flatMap(MHAppVersion.init) }
        )
    }
}
