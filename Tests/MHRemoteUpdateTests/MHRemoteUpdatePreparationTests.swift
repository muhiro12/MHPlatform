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
        #expect(first.evaluation.restorationError != nil)
        #expect(first.refreshError == nil)
        #expect(first.decision == .notRequired)
        try Data("corrupt again".utf8).write(to: fileURL)
        let second = try await updates.prepare()
        #expect(second.restorationError == nil)
        #expect(second.evaluation.restorationError != nil)
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
            requirement: .init(
                minimumVersion: #require(MHAppVersion("2")), effectiveAt: .init(timeIntervalSinceReferenceDate: 0)
            )
        )
        try store.save(.init(
            schedule: schedule,
            storefront: "jp",
            observation: .init(
                fetchedAt: .init(timeIntervalSinceReferenceDate: 0),
                validUntil: .init(timeIntervalSinceReferenceDate: 100)
            ),
            publication: .init(
                version: #require(MHAppVersion("2")),
                checkedAt: .init(timeIntervalSinceReferenceDate: 0),
                validUntil: .init(timeIntervalSinceReferenceDate: 20)
            )
        ))
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
        let snapshot = MHRemoteUpdateSnapshot(
            schedule: try schedule(),
            storefront: "jp",
            observation: .init(
                fetchedAt: .init(timeIntervalSinceReferenceDate: 0),
                validUntil: .init(timeIntervalSinceReferenceDate: 100)
            ),
            publication: nil
        )
        try store.save(snapshot)
        #expect(try store.load() == snapshot)
    }

    @Test
    func preparationRetriesReadingEvidenceAfterTheFileBecomesReadable() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let fileURL = directory.appendingPathComponent("policy.json")
        try FileManager.default.createDirectory(at: fileURL, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        let store = MHRemoteUpdateStore(fileURL: fileURL)
        let updates = try controller(store: store) { throw ExpectedFailure.offline }
        let first = try await updates.prepare()
        #expect(first.restorationError != nil)
        #expect(first.refreshError is ExpectedFailure)
        try FileManager.default.removeItem(at: fileURL)
        try store.save(.init(
            schedule: MHRemoteUpdateSchedule(
                bundleIdentifier: "example.app",
                revision: 1,
                requirement: .init(
                    minimumVersion: #require(MHAppVersion("2")),
                    effectiveAt: .init(timeIntervalSinceReferenceDate: 0)
                )
            ),
            storefront: "jp",
            observation: .init(
                fetchedAt: .init(timeIntervalSinceReferenceDate: 0),
                validUntil: .init(timeIntervalSinceReferenceDate: 100)
            ),
            publication: .init(
                version: #require(MHAppVersion("2")),
                checkedAt: .init(timeIntervalSinceReferenceDate: 0),
                validUntil: .init(timeIntervalSinceReferenceDate: 20)
            )
        ))
        let recovered = try await updates.prepare()
        #expect(recovered.restorationError == nil)
        #expect(recovered.refreshError is ExpectedFailure)
        #expect(recovered.decision == .updateRequired)
    }

    private func controller(
        store: MHRemoteUpdateStore? = nil,
        fetch: @escaping @Sendable () async throws -> MHRemoteUpdateSchedule
    ) throws -> MHRemoteUpdateController {
        let publication: @Sendable () async -> MHAppVersion? = { nil }
        return try .init(
            bundleIdentifier: "example.app",
            storefront: "jp",
            policyLifetime: 100,
            publicationLifetime: 20,
            store: store,
            currentVersion: { "1" },
            now: { .init(timeIntervalSinceReferenceDate: 10) },
            fetchSchedule: {
                .init(value: try await fetch(), fetchedAt: .init(timeIntervalSinceReferenceDate: 10))
            },
            publicVersion: publication
        )
    }

    private func schedule() throws -> MHRemoteUpdateSchedule {
        try .init(
            bundleIdentifier: "example.app",
            revision: 1,
            requirement: nil
        )
    }
}
