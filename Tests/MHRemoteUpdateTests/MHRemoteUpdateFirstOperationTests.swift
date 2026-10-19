import Foundation
import MHRemoteUpdate
import Synchronization
import Testing

struct MHRemoteUpdateFirstOperationTests: Sendable {
    private enum Limits {
        static let now: TimeInterval = 10
        static let policyAge: TimeInterval = 100
        static let publicationAge: TimeInterval = 20
    }

    private struct Cache {
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)

        var store: MHRemoteUpdateStore { .init(fileURL: fileURL) }

        func remove() {
            try? FileManager.default.removeItem(at: fileURL)
        }
    }

    @Test
    func concurrentFirstChecksUseRetainedPermissionOfflineWithoutAppPreparation() async throws {
        let cache = Cache()
        defer {
            cache.remove()
        }
        let original = try snapshot()
        try cache.store.save(original)
        let fetches = Mutex(0)
        let updates = try controller(store: cache.store) {
            fetches.withLock { $0 += 1 }
            throw RemoteUpdateTestSupport.Failure.offline
        }
        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<10 {
                group.addTask { try await updates.checkOperationAllowed() }
            }
            try await group.waitForAll()
        }
        #expect(fetches.withLock { $0 } == 0)
        #expect(await updates.evaluation().observation == original.observation)
        #expect(try cache.store.load() == original)
        try Data("corrupt after initialization".utf8).write(to: cache.fileURL)
        try await updates.checkOperationAllowed()
        #expect(await updates.evaluation().restorationError != nil)
        #expect(await updates.evaluation().observation == original.observation)
    }

    @Test(arguments: [false, true])
    func retainedBaselineOrPlanBlocksTheFirstOperationWithoutFetching(_ planned: Bool) async throws {
        let cache = Cache()
        defer {
            cache.remove()
        }
        let original = try snapshot(minimum: "2", planned: planned)
        try cache.store.save(original)
        let updates = try controller(store: cache.store) {
            Issue.record("A known required update must block without a network request")
            throw RemoteUpdateTestSupport.Failure.offline
        }
        for policy in [MHRemoteUpdateOperationPolicy.requireConfirmation, .allowWhenUnavailable] {
            await #expect(throws: MHRemoteUpdateOperationError.updateRequired) {
                try await updates.checkOperationAllowed(for: policy)
            }
        }
        #expect(await updates.evaluation().reason == .updateRequired)
        #expect(try cache.store.load() == original)
    }

    @Test(arguments: ["missing", "corrupt", "identity", "storefront", "expired", "publicationExpired"], [false, true])
    func unusableStorageRequiresOneValidatedRefreshAndPreservesFailures(
        _ scenario: String, _ online: Bool
    ) async throws {
        let cache = Cache()
        defer {
            cache.remove()
        }
        switch scenario {
        case "corrupt":
            try Data("corrupt".utf8).write(to: cache.fileURL)
        case "identity":
            try cache.store.save(snapshot(bundleIdentifier: "other.app", minimum: "2"))
        case "storefront":
            try cache.store.save(snapshot(storefront: "jp", minimum: "2"))
        case "expired":
            try cache.store.save(snapshot(minimum: "2", policyUntil: 10))
        case "publicationExpired":
            try cache.store.save(snapshot(minimum: "2", publicationUntil: 10))
        default:
            break
        }
        let permission = try snapshot(revision: 3).schedule
        let fetches = Mutex(0)
        let updates = try controller(store: cache.store) {
            fetches.withLock { $0 += 1 }
            if online == false {
                throw RemoteUpdateTestSupport.Failure.offline
            }
            return permission
        }
        if online {
            try await updates.checkOperationAllowed()
        } else {
            await #expect(throws: RemoteUpdateTestSupport.Failure.self) {
                try await updates.checkOperationAllowed()
            }
        }
        let evaluation = await updates.evaluation()
        #expect(fetches.withLock { $0 } == 1)
        #expect(evaluation.decision == (online ? .notRequired : .unavailable))
        #expect((evaluation.restorationError != nil) == ["corrupt", "identity", "storefront"].contains(scenario))
        #expect((evaluation.refreshError != nil) == (online == false))
    }

    @Test(arguments: [MHRemoteUpdateUnavailableBehavior.allow, .block])
    func explicitUnavailablePoliciesStillApplyWithoutNetworking(
        _ behavior: MHRemoteUpdateUnavailableBehavior
    ) async throws {
        let cache = Cache()
        defer {
            cache.remove()
        }
        try Data("corrupt".utf8).write(to: cache.fileURL)
        let updates = try controller(store: cache.store) {
            Issue.record("No refresh is requested for this operation")
            throw RemoteUpdateTestSupport.Failure.offline
        }
        if behavior == .allow {
            try await updates.checkOperationAllowed(whenUnavailable: behavior, refreshIfUnavailable: false)
        } else {
            await #expect(throws: MHRemoteUpdateOperationError.policyUnavailable) {
                try await updates.checkOperationAllowed(whenUnavailable: behavior, refreshIfUnavailable: false)
            }
        }
        #expect(await updates.evaluation().restorationError != nil)
        #expect(await updates.decision() == .unavailable)
    }

    @Test
    func failedInitializationCanRecoverFromARepairedFileWithoutAnotherFetch() async throws {
        let cache = Cache()
        defer {
            cache.remove()
        }
        try Data("corrupt".utf8).write(to: cache.fileURL)
        let fetches = Mutex(0)
        let updates = try controller(store: cache.store) {
            fetches.withLock { $0 += 1 }
            throw RemoteUpdateTestSupport.Failure.offline
        }
        await #expect(throws: RemoteUpdateTestSupport.Failure.self) {
            try await updates.checkOperationAllowed()
        }
        try cache.store.save(snapshot())
        try await updates.checkOperationAllowed()
        let evaluation = await updates.evaluation()
        #expect(evaluation.decision == .notRequired)
        #expect(evaluation.restorationError == nil)
        #expect(evaluation.refreshError is RemoteUpdateTestSupport.Failure)
        #expect(fetches.withLock { $0 } == 1)
    }

    @Test
    func aCancelledFirstCheckNeitherRestoresNorPoisonsTheNextCheck() async throws {
        let cache = Cache()
        defer {
            cache.remove()
        }
        try cache.store.save(snapshot())
        let original = try Data(contentsOf: cache.fileURL)
        let updates = try controller(store: cache.store) {
            Issue.record("Neither the cancelled nor the retained-permission check needs a fetch")
            throw RemoteUpdateTestSupport.Failure.offline
        }
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            try await updates.checkOperationAllowed()
        }
        await #expect(throws: CancellationError.self) {
            try await task.value
        }
        #expect(await updates.evaluation().reason == .policyMissing)
        #expect(try Data(contentsOf: cache.fileURL) == original)
        try await updates.checkOperationAllowed()
        #expect(await updates.decision() == .notRequired)
    }

    @Test
    func expiredRetainedRevisionsStillRejectARemoteRollbackOnTheFirstCheck() async throws {
        let cache = Cache()
        defer {
            cache.remove()
        }
        let original = try snapshot(revision: 3, policyUntil: 10)
        try cache.store.save(original)
        let obsolete = try snapshot(revision: 2).schedule
        let updates = try controller(store: cache.store) { obsolete }
        await #expect(throws: MHRemoteUpdateController.Failure.revisionConflict) {
            try await updates.checkOperationAllowed()
        }
        #expect(await updates.evaluation().revision == 3)
        #expect(await updates.decision() == .unavailable)
        #expect(try cache.store.load() == original)
    }
}

private extension MHRemoteUpdateFirstOperationTests {
    func date(_ second: Double) -> Date {
        .init(timeIntervalSinceReferenceDate: second)
    }

    func snapshot(
        bundleIdentifier: String = "example.app",
        storefront: String? = nil,
        revision: Int = 1,
        minimum: String? = nil,
        planned: Bool = false,
        policyUntil: Double = Limits.policyAge,
        publicationUntil: Double = Limits.publicationAge
    ) throws -> MHRemoteUpdateSnapshot {
        let requirement = try minimum.map { minimum in
            MHRemoteUpdateSchedule.Requirement(
                minimumVersion: try #require(MHAppVersion(minimum)),
                effectiveAt: date(planned ? Limits.now : 0)
            )
        }
        let schedule = try MHRemoteUpdateSchedule(
            bundleIdentifier: bundleIdentifier,
            revision: revision,
            requirement: planned ? nil : requirement,
            scheduledRequirements: planned ? requirement.map { [$0] } ?? [] : []
        )
        return .init(
            schedule: schedule,
            storefront: storefront,
            observation: .init(fetchedAt: date(0), validUntil: date(policyUntil)),
            publication: requirement.map { requirement in
                .init(version: requirement.minimumVersion, checkedAt: date(0), validUntil: date(publicationUntil))
            }
        )
    }

    func controller(
        store: MHRemoteUpdateStore,
        fetch: @escaping @Sendable () async throws -> MHRemoteUpdateSchedule
    ) throws -> MHRemoteUpdateController {
        try .init(
            bundleIdentifier: "example.app",
            storefront: nil,
            policyLifetime: Limits.policyAge,
            publicationLifetime: Limits.publicationAge,
            store: store,
            currentVersion: { "1" },
            now: { .init(timeIntervalSinceReferenceDate: Limits.now) },
            fetchSchedule: {
                .init(value: try await fetch(), fetchedAt: .init(timeIntervalSinceReferenceDate: Limits.now))
            },
            publicVersion: { nil }
        )
    }
}
