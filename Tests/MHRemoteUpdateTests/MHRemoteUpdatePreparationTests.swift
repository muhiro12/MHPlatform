import Foundation
import MHRemoteUpdate
import Testing

struct MHRemoteUpdatePreparationTests: Sendable {
    private enum ExpectedFailure: Error {
        case offline
    }

    @Test
    func corruptCacheDoesNotPreventRefreshAndRestorationIsAttemptedOnce() async throws {
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer {
            try? FileManager.default.removeItem(at: fileURL)
        }
        try Data("corrupt".utf8).write(to: fileURL)
        let updates = try controller(store: .init(fileURL: fileURL)) { try schedule() }
        let first = try await updates.prepare()
        #expect(first.restorationError != nil)
        #expect(first.refreshError == nil)
        #expect(first.decision == .notRequired)
        try Data("corrupt again".utf8).write(to: fileURL)
        let second = try await updates.prepare()
        #expect(second.restorationError == nil)
        #expect(second.decision == .notRequired)
    }

    @Test
    func unavailableCacheAndNetworkRemainUsableForLowImpactOperations() async throws {
        let updates = try controller { throw ExpectedFailure.offline }
        let result = try await updates.prepare()
        #expect(result.decision == .unavailable)
        #expect(result.restorationError == nil)
        #expect(result.refreshError is ExpectedFailure)
        try await updates.checkOperationAllowed(for: .allowWhenUnavailable)
        await #expect(throws: ExpectedFailure.self) {
            try await updates.checkOperationAllowed()
        }
    }

    @Test
    func failedPreparationKeepsRestoredUpdateRequirement() async throws {
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer {
            try? FileManager.default.removeItem(at: fileURL)
        }
        let store = MHRemoteUpdateStore(fileURL: fileURL)
        let schedule = try MHRemoteUpdateSchedule(
            bundleIdentifier: "example.app",
            revision: 1,
            issuedAt: .init(timeIntervalSinceReferenceDate: 0),
            validUntil: .init(timeIntervalSinceReferenceDate: 100),
            requirement: .init(
                minimumVersion: #require(MHAppVersion("2")), effectiveAt: .init(timeIntervalSinceReferenceDate: 0)
            )
        )
        try store.save(.init(schedule: schedule, storefront: "jp", publication: .init(
            version: #require(MHAppVersion("2")),
            checkedAt: .init(timeIntervalSinceReferenceDate: 0),
            validUntil: .init(timeIntervalSinceReferenceDate: 20)
        )))
        let updates = try controller(store: store) { throw ExpectedFailure.offline }
        let result = try await updates.prepare()
        #expect(result.decision == .updateRequired)
        #expect(result.refreshError is ExpectedFailure)
        await #expect(throws: MHRemoteUpdateOperationError.updateRequired) {
            try await updates.checkOperationAllowed(for: .allowWhenUnavailable)
        }
    }

    @Test
    func cancelledPreparationDoesNotReturnAnOrdinaryResult() async throws {
        let updates = try controller {
            withUnsafeCurrentTask { $0?.cancel() }
            return try schedule()
        }
        let task = Task { try await updates.prepare() }
        await #expect(throws: CancellationError.self) {
            try await task.value
        }
        #expect(await updates.decision() == .unavailable)
    }

    @Test
    func storeCreatesMissingParentsWithoutAppSetup() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        let store = MHRemoteUpdateStore(fileURL: directory.appendingPathComponent("nested/policy.json"))
        let snapshot = MHRemoteUpdateSnapshot(schedule: try schedule(), storefront: "jp", publication: nil)
        try store.save(snapshot)
        #expect(try store.load() == snapshot)
    }

    private func controller(
        store: MHRemoteUpdateStore? = nil,
        fetch: @escaping @Sendable () async throws -> MHRemoteUpdateSchedule
    ) throws -> MHRemoteUpdateController {
        let publication: @Sendable () async -> MHAppVersion? = { nil }
        return try .init(
            bundleIdentifier: "example.app",
            storefront: "jp",
            maximumValidity: 100,
            publicationLifetime: 20,
            store: store,
            currentVersion: { "1" },
            now: { .init(timeIntervalSinceReferenceDate: 10) },
            fetchSchedule: fetch,
            publicVersion: publication
        )
    }

    private func schedule() throws -> MHRemoteUpdateSchedule {
        try .init(
            bundleIdentifier: "example.app",
            revision: 1,
            issuedAt: .init(timeIntervalSinceReferenceDate: 0),
            validUntil: .init(timeIntervalSinceReferenceDate: 100),
            requirement: nil
        )
    }
}
