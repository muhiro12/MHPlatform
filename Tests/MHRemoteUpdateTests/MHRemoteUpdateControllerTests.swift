import Foundation
import MHRemoteUpdate
import Synchronization
import Testing

struct MHRemoteUpdateControllerTests: Sendable {
    private final class Clock: Sendable {
        private let value: Mutex<Date>

        init(_ date: Date) {
            value = .init(date)
        }

        func now() -> Date {
            value.withLock { $0 }
        }

        func set(_ date: Date) {
            value.withLock { $0 = date }
        }
    }

    private enum ExpectedFailure: Error {
        case offline
    }

    @Test
    func unknownOperationsAllowBlockOrRefreshExactlyOnce() async throws {
        let calls = Mutex(0)
        let controller = try controller {
            calls.withLock { $0 += 1 }
            return try schedule(requirement: false)
        }
        try await controller.checkOperationAllowed(whenUnavailable: .allow, refreshIfUnavailable: false)
        await #expect(throws: MHRemoteUpdateOperationError.policyUnavailable) {
            try await controller.checkOperationAllowed(whenUnavailable: .block, refreshIfUnavailable: false)
        }
        #expect(calls.withLock { $0 } == 0)
        try await controller.checkOperationAllowed(whenUnavailable: .block, refreshIfUnavailable: true)
        #expect(calls.withLock { $0 } == 1)
        try await controller.checkOperationAllowed(whenUnavailable: .block, refreshIfUnavailable: true)
        #expect(calls.withLock { $0 } == 1)
    }

    @Test(arguments: [MHRemoteUpdateUnavailableBehavior.allow, .block])
    func knownRequiredAlwaysBlocksWithoutRefreshing(_ behavior: MHRemoteUpdateUnavailableBehavior) async throws {
        let controller = try controller()
        #expect(try await controller.refresh() == .updateRequired)
        await #expect(throws: MHRemoteUpdateOperationError.updateRequired) {
            try await controller.checkOperationAllowed(whenUnavailable: behavior, refreshIfUnavailable: true)
        }
    }

    @Test(arguments: [nil, "5"])
    func missingOrUnpublishedVersionRemainsUnknownAfterOneRefresh(_ publicVersion: String?) async throws {
        let lookup: @Sendable () async -> MHAppVersion? = { publicVersion.flatMap(MHAppVersion.init) }
        let controller = try controller(publicVersion: lookup)
        await #expect(throws: MHRemoteUpdateOperationError.policyUnavailable) {
            try await controller.checkOperationAllowed(whenUnavailable: .block, refreshIfUnavailable: true)
        }
        #expect(await controller.decision() == .unavailable)
    }

    @Test
    func failedRefreshRetainsRequiredEvidenceUntilItExpires() async throws {
        let clock = Clock(date(10))
        let offline = Mutex(false)
        let controller = try controller(clock: clock) {
            if offline.withLock({ $0 }) {
                throw ExpectedFailure.offline
            }
            return try schedule()
        }
        try await controller.refresh()
        offline.withLock { $0 = true }
        await #expect(throws: ExpectedFailure.self) {
            try await controller.refresh()
        }
        #expect(await controller.decision() == .updateRequired)
        clock.set(date(30))
        #expect(await controller.decision() == .unavailable)
    }

    @Test
    func storedPlanActivatesAfterRestartAndCancellationCannotBeRolledBack() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        let store = MHRemoteUpdateStore(fileURL: directory.appendingPathComponent("policy.json"))
        let clock = Clock(date(5))
        let controller = try controller(clock: clock, store: store)
        #expect(try await controller.refresh() == .notRequired)
        clock.set(date(10))
        let revision = Mutex(2)
        let restored = try self.controller(clock: clock, store: store) {
            try schedule(revision: revision.withLock { $0 }, requirement: false)
        }
        try await restored.restore()
        #expect(await restored.decision() == .updateRequired)
        #expect(try await restored.refresh() == .notRequired)
        revision.withLock { $0 = 1 }
        await #expect(throws: MHRemoteUpdateController.Failure.revisionConflict) {
            try await restored.refresh()
        }
        #expect(await restored.decision() == .notRequired)
        let restarted = try self.controller(clock: clock, store: store)
        try await restarted.restore()
        #expect(await restarted.decision() == .notRequired)
    }

    @Test
    func changedRevisionContentAndWrongIdentityNeverReplaceEvidence() async throws {
        let response = Mutex(try schedule())
        let controller = try controller { response.withLock { $0 } }
        try await controller.refresh()
        let cancellation = try schedule(requirement: false)
        response.withLock { $0 = cancellation }
        await #expect(throws: MHRemoteUpdateController.Failure.revisionConflict) {
            try await controller.refresh()
        }
        let foreign = try MHRemoteUpdateSchedule(
            bundleIdentifier: "other.app", revision: 2, issuedAt: date(0), validUntil: date(100), requirement: nil
        )
        response.withLock { $0 = foreign }
        await #expect(throws: MHRemoteUpdateController.Failure.identityMismatch) {
            try await controller.refresh()
        }
        #expect(await controller.decision() == .updateRequired)
    }

    @Test
    func cancellationBeforeAcceptingResponseDoesNotGrantPermission() async throws {
        let controller = try controller {
            withUnsafeCurrentTask { $0?.cancel() }
            return try schedule(requirement: false)
        }
        let task = Task {
            try await controller.checkOperationAllowed(whenUnavailable: .block, refreshIfUnavailable: true)
        }
        await #expect(throws: CancellationError.self) {
            try await task.value
        }
        #expect(await controller.decision() == .unavailable)
    }

    @Test
    func timeIsResampledAfterLookupAndExpiredScheduleIsUnknown() async throws {
        let clock = Clock(date(5))
        let lookup: @Sendable () async -> MHAppVersion? = {
            clock.set(date(100))
            return MHAppVersion("6")
        }
        let controller = try controller(clock: clock, publicVersion: lookup)
        #expect(try await controller.refresh() == .unavailable)
    }

    @Test
    func publicationFailureStillPersistsAnnouncedPlan() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        let store = MHRemoteUpdateStore(fileURL: directory.appendingPathComponent("policy.json"))
        let clock = Clock(date(5))
        let lookup: @Sendable () async throws -> MHAppVersion? = { throw ExpectedFailure.offline }
        let controller = try controller(clock: clock, store: store, publicVersion: lookup)
        await #expect(throws: ExpectedFailure.self) {
            try await controller.refresh()
        }
        #expect(try store.load()?.schedule.revision == 1)
        #expect(await controller.decision() == .notRequired)
        clock.set(date(10))
        #expect(await controller.decision() == .unavailable)
    }

    @Test
    func expiredOrExcessiveScheduleDoesNotBecomePermission() async throws {
        let clock = Clock(date(100))
        let controller = try controller(clock: clock)
        await #expect(throws: MHRemoteUpdateController.Failure.invalidSchedule) {
            try await controller.refresh()
        }
        #expect(await controller.decision() == .unavailable)
    }

    private func controller(
        clock: Clock = .init(.init(timeIntervalSinceReferenceDate: 10)),
        store: MHRemoteUpdateStore? = nil,
        fetch: (@Sendable () async throws -> MHRemoteUpdateSchedule)? = nil,
        publicVersion: @escaping @Sendable () async throws -> MHAppVersion? = { MHAppVersion("6") }
    ) throws -> MHRemoteUpdateController {
        try .init(
            bundleIdentifier: "example.app",
            storefront: "JP",
            maximumValidity: 100,
            publicationLifetime: 20,
            store: store,
            currentVersion: { "5" },
            now: { clock.now() },
            fetchSchedule: fetch ?? { try schedule() },
            publicVersion: publicVersion
        )
    }

    private func schedule(revision: Int = 1, requirement: Bool = true) throws -> MHRemoteUpdateSchedule {
        try .init(
            bundleIdentifier: "example.app",
            revision: revision,
            issuedAt: date(0),
            validUntil: date(100),
            requirement: requirement ? .init(minimumVersion: #require(MHAppVersion("6")), effectiveAt: date(10)) : nil
        )
    }

    private func date(_ seconds: Double) -> Date {
        .init(timeIntervalSinceReferenceDate: seconds)
    }
}
