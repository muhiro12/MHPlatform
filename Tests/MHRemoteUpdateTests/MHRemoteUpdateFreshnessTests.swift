import Foundation
import MHRemoteUpdate
import Synchronization
import Testing

struct MHRemoteUpdateFreshnessTests: Sendable {
    private typealias Fixture = RemoteUpdateTestSupport

    @Test(arguments: [nil, "1"])
    func unchangedPolicyCanBeFetchedBeyondThirtyDaysWithoutReissuingIt(_ minimum: String?) async throws {
        let clock = Fixture.Clock()
        let policy = try makePolicy(minimum: minimum)
        let fetches = Mutex(0)
        let updates = try makeController(clock: clock) {
            fetches.withLock { $0 += 1 }
            return policy
        }
        #expect(try await updates.refresh() == .notRequired)
        clock.set(day: 31)
        #expect(await updates.decision() == .unavailable)
        #expect(try await updates.refresh() == .notRequired)
        #expect(fetches.withLock { $0 } == 2)
        clock.set(day: 60)
        #expect(await updates.decision() == .notRequired)
        clock.set(day: 61)
        #expect(await updates.decision() == .unavailable)
    }

    @Test
    func futureActivationAndRequirementEndRemainAbsolute() async throws {
        let clock = Fixture.Clock()
        let policy = try makePolicy(minimum: "2", activationDay: 14, endDay: 16)
        let updates = try makeController(clock: clock, publicationDays: 30) { policy }
        #expect(try await updates.refresh() == .notRequired)
        clock.set(day: 14)
        #expect(await updates.decision() == .updateRequired)
        clock.set(day: 16)
        #expect(await updates.decision() == .updateRequired)
        clock.set(day: 17)
        #expect(await updates.decision() == .notRequired)
        clock.set(day: 30)
        #expect(await updates.decision() == .unavailable)
    }

    @Test
    func postponementCancellationAndRevisionConflictsPreserveImmutableIdentity() async throws {
        let clock = Fixture.Clock()
        let policy = Mutex(try makePolicy(minimum: "2"))
        let updates = try makeController(clock: clock) { policy.withLock { $0 } }
        #expect(try await updates.refresh() == .updateRequired)
        let postponed = try makePolicy(revision: 2, minimum: "2", activationDay: 20)
        policy.withLock { $0 = postponed }
        #expect(try await updates.refresh() == .notRequired)
        let conflict = try makePolicy(revision: 2)
        policy.withLock { $0 = conflict }
        await #expect(throws: MHRemoteUpdateController.Failure.revisionConflict) {
            try await updates.refresh()
        }
        clock.set(day: 31)
        let replay = try makePolicy(minimum: "2")
        policy.withLock { $0 = replay }
        await #expect(throws: MHRemoteUpdateController.Failure.revisionConflict) {
            try await updates.refresh()
        }
        #expect(await updates.decision() == .unavailable)
        let cancellation = try makePolicy(revision: 3)
        policy.withLock { $0 = cancellation }
        #expect(try await updates.refresh() == .notRequired)
    }

    @Test(arguments: [nil, "1"])
    func missingOrUnpublishedMinimumCannotAuthorizeAnOperation(_ publicVersion: String?) async throws {
        let clock = Fixture.Clock()
        let policy = try makePolicy(minimum: "2")
        let lookup: @Sendable () async -> MHAppVersion? = { publicVersion.flatMap(MHAppVersion.init) }
        let updates = try makeController(clock: clock, fetch: { policy }, publicVersion: lookup)
        #expect(try await updates.refresh() == .unavailable)
        await #expect(throws: MHRemoteUpdateOperationError.policyUnavailable) {
            try await updates.checkOperationAllowed()
        }
    }

    @Test
    func failedPublicationRefreshPreservesOnlyUnexpiredPublicationEvidence() async throws {
        let clock = Fixture.Clock()
        let policy = try makePolicy(minimum: "2")
        let offline = Mutex(false)
        let lookup: @Sendable () async throws -> MHAppVersion? = {
            if offline.withLock({ $0 }) {
                throw Fixture.Failure.offline
            }
            return MHAppVersion("2")
        }
        let updates = try makeController(clock: clock, fetch: { policy }, publicVersion: lookup)
        #expect(try await updates.refresh() == .updateRequired)
        clock.set(day: 0.5)
        offline.withLock { $0 = true }
        await #expect(throws: Fixture.Failure.self) {
            try await updates.refresh()
        }
        #expect(await updates.decision() == .updateRequired)
        clock.set(day: 1)
        #expect(await updates.decision() == .unavailable)
        await #expect(throws: Fixture.Failure.self) {
            try await updates.refresh()
        }
        #expect(await updates.decision() == .unavailable)
    }

    @Test
    func policyFetchFailuresDoNotRenewEvidenceAndLowImpactUseRemainsExplicit() async throws {
        let clock = Fixture.Clock()
        let policy = try makePolicy()
        let offline = Mutex(false)
        let updates = try makeController(clock: clock) {
            if offline.withLock({ $0 }) {
                throw Fixture.Failure.offline
            }
            return policy
        }
        try await updates.refresh()
        offline.withLock { $0 = true }
        clock.set(day: 20)
        await #expect(throws: Fixture.Failure.self) {
            try await updates.refresh()
        }
        #expect(await updates.decision() == .notRequired)
        clock.set(day: 30)
        #expect(await updates.decision() == .unavailable)
        try await updates.checkOperationAllowed(for: .allowWhenUnavailable)
        await #expect(throws: Fixture.Failure.self) {
            try await updates.checkOperationAllowed()
        }
    }

    @Test
    func cancelledPolicyFetchDoesNotRetainPermission() async throws {
        let clock = Fixture.Clock()
        let policy = try makePolicy()
        let updates = try makeController(clock: clock) {
            withUnsafeCurrentTask { $0?.cancel() }
            return policy
        }
        let task = Task { try await updates.prepare() }
        await #expect(throws: CancellationError.self) {
            try await task.value
        }
        #expect(await updates.decision() == .unavailable)
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
            fetchSchedule: fetch,
            publicVersion: publicVersion
        )
    }
}
