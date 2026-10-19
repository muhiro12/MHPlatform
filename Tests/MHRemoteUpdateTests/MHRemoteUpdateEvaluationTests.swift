import Foundation
import MHRemoteUpdate
import Synchronization
import Testing

struct MHRemoteUpdateEvaluationTests: Sendable {
    private enum Limits {
        static let policyAge: TimeInterval = 100
        static let publicationAge: TimeInterval = 20
        static let now: TimeInterval = 10
    }

    @Test(arguments: [
        (10.0, 100.0, 20.0, Optional("2"), MHRemoteUpdateEvaluation.Reason.updateRequired),
        (100, 100, 20, "2", .policyExpired),
        (10, 10, 20, "2", .policyExpired),
        (20, 100, 20, "2", .publicationExpired),
        (10, 100, 10, "2", .publicationExpired),
        (10, 100, 20, nil, .publicationMissing),
        (10, 100, 20, "1", .publicationInsufficient),
        (-1, 100, 20, "2", .policyInvalid)
    ])
    func explainsFreshnessAndPublicationFromTheOrdinaryEvaluation(
        _ second: Double,
        _ policyAge: Double,
        _ publicationAge: Double,
        _ published: String?,
        _ reason: MHRemoteUpdateEvaluation.Reason
    ) throws {
        let snapshot = try snapshot(published: published)
        let version = try #require(MHAppVersion("1"))
        let evaluation = snapshot.evaluation(
            currentVersion: version,
            now: date(second),
            maximumPolicyAge: policyAge,
            maximumPublicationAge: publicationAge
        )
        #expect(evaluation.reason == reason)
        #expect(evaluation.decision == (reason == .updateRequired ? .updateRequired : .unavailable))
        #expect(evaluation.revision == 1)
        #expect(evaluation.evaluatedAt == date(second))
        #expect(evaluation.observation == snapshot.observation)
        #expect(evaluation.publication == snapshot.publication)
        #expect(snapshot.evaluate(
            currentVersion: version,
            now: date(second),
            maximumPolicyAge: policyAge,
            maximumPublicationAge: publicationAge
        ) == evaluation.decision)
    }

    @Test(arguments: [0.0, 10, 20, 21])
    func activeMinimumMetadataTracksPlansAndTheirInclusiveBoundaries(_ second: Double) throws {
        let schedule = try MHRemoteUpdateSchedule(
            bundleIdentifier: "example.app",
            revision: 2,
            requirement: .init(minimumVersion: #require(MHAppVersion("2")), effectiveAt: date(0)),
            scheduledRequirements: [.init(
                minimumVersion: #require(MHAppVersion("3")), effectiveAt: date(10), endsAt: date(20)
            )]
        )
        let snapshot = try snapshot(schedule: schedule, published: "3", publicationUntil: 100)
        let version = try #require(MHAppVersion("2"))
        let evaluation = snapshot.evaluation(
            currentVersion: version,
            now: date(second),
            maximumPolicyAge: 100,
            maximumPublicationAge: 100
        )
        let planIsActive = second >= 10 && second <= 20
        #expect(evaluation.minimumVersion == MHAppVersion(planIsActive ? "3" : "2"))
        #expect(evaluation.reason == (planIsActive ? .updateRequired : .installedVersionAccepted))
        #expect(evaluation.revision == 2)
        #expect(evaluation.policyFreshness == .fresh)
    }

    @Test
    func cancellationAndCompliantVersionsNeedNoPublication() throws {
        let version = try #require(MHAppVersion("2"))
        let cancelled = try snapshot(schedule: .init(bundleIdentifier: "example.app", revision: 2, requirement: nil))
        let cleared = cancelled.evaluation(
            currentVersion: version,
            now: date(10),
            maximumPolicyAge: 100,
            maximumPublicationAge: 20
        )
        #expect(cleared.reason == .noActiveRequirement)
        #expect(cleared.minimumVersion == nil)
        #expect(cleared.decision == .notRequired)
        let compliant = try snapshot().evaluation(
            currentVersion: version,
            now: date(10),
            maximumPolicyAge: 100,
            maximumPublicationAge: 20
        )
        #expect(compliant.reason == .installedVersionAccepted)
        #expect(compliant.publicationFreshness == .missing)
        #expect(compliant.decision == .notRequired)
    }

    @Test
    func publicationFromTheFutureRemainsInvalidRatherThanPermission() throws {
        let original = try snapshot(published: "2")
        let publishedVersion = try #require(MHAppVersion("2"))
        let snapshot = MHRemoteUpdateSnapshot(
            schedule: original.schedule,
            storefront: nil,
            observation: original.observation,
            publication: .init(
                version: publishedVersion, checkedAt: date(11), validUntil: date(20)
            )
        )
        let version = try #require(MHAppVersion("1"))
        let result = snapshot.evaluation(
            currentVersion: version,
            now: date(10),
            maximumPolicyAge: 100,
            maximumPublicationAge: 20
        )
        #expect(result.reason == .publicationInvalid)
        #expect(result.publicationFreshness == .invalid)
        #expect(result.decision == .unavailable)
    }

    @Test(arguments: [Optional("1"), nil, "invalid"])
    func absentEvidenceAndInvalidInstalledVersionsAreExplicit(_ installed: String?) async throws {
        let updates = try controller(installed: installed) {
            throw RemoteUpdateTestSupport.Failure.offline
        }
        let result = await updates.evaluation()
        #expect(result.reason == (installed == "1" ? .policyMissing : .installedVersionInvalid))
        #expect(result.revision == nil)
        #expect(result.minimumVersion == nil)
        #expect(result.policyFreshness == .missing)
        #expect(result.decision == .unavailable)
    }

    @Test
    func diagnosticReadsUseOneInstantAndNeverRestoreFetchSaveOrRenewEvidence() async throws {
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer {
            try? FileManager.default.removeItem(at: fileURL)
        }
        let store = MHRemoteUpdateStore(fileURL: fileURL)
        let original = try snapshot(published: "2")
        try store.save(original)
        let bytes = try Data(contentsOf: fileURL)
        let clockReads = Mutex(0)
        let networkReads = Mutex(0)
        let updates = try controller(
            store: store,
            now: {
                let offset = clockReads.withLock { value in
                    defer {
                        value += 1
                    }
                    return value
                }
                return date(10 + Double(offset))
            }, fetch: {
                networkReads.withLock { $0 += 1 }
                throw RemoteUpdateTestSupport.Failure.offline
            })
        #expect(await updates.evaluation().reason == .policyMissing)
        try await updates.restore()
        let result = await updates.evaluation()
        #expect(result.evaluatedAt == date(11))
        #expect(result.reason == .updateRequired)
        #expect(result.observation == original.observation)
        #expect(clockReads.withLock { $0 } == 2)
        #expect(networkReads.withLock { $0 } == 0)
        #expect(try Data(contentsOf: fileURL) == bytes)
        let cancelledRead = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return await updates.evaluation()
        }
        #expect(await cancelledRead.value.reason == .updateRequired)
    }

    @Test
    func failedRefreshRemainsObservableWithoutDiscardingRetainedPolicy() async throws {
        let schedule = try snapshot().schedule
        let failing = Mutex(false)
        let updates = try controller {
            if failing.withLock({ $0 }) {
                throw RemoteUpdateTestSupport.Failure.offline
            }
            return schedule
        }
        let prepared = try await updates.prepare()
        #expect(prepared.evaluation.decision == prepared.decision)
        failing.withLock { $0 = true }
        await #expect(throws: RemoteUpdateTestSupport.Failure.self) {
            try await updates.refresh()
        }
        let failed = await updates.evaluation()
        #expect(failed.reason == .publicationMissing)
        #expect(failed.refreshError is RemoteUpdateTestSupport.Failure)
        failing.withLock { $0 = false }
        try await updates.refresh()
        #expect(await updates.evaluation().refreshError == nil)
    }
}

private extension MHRemoteUpdateEvaluationTests {
    func date(_ second: Double) -> Date {
        .init(timeIntervalSinceReferenceDate: second)
    }

    func snapshot(
        schedule: MHRemoteUpdateSchedule? = nil, published: String? = nil, publicationUntil: Double = 20
    ) throws -> MHRemoteUpdateSnapshot {
        let policy: MHRemoteUpdateSchedule = try schedule ?? .init(
            bundleIdentifier: "example.app",
            revision: 1,
            requirement: .init(minimumVersion: #require(MHAppVersion("2")), effectiveAt: date(0))
        )
        return .init(
            schedule: policy,
            storefront: nil,
            observation: .init(fetchedAt: date(0), validUntil: date(100)),
            publication: published.flatMap(MHAppVersion.init).map { version in
                .init(version: version, checkedAt: date(0), validUntil: date(publicationUntil))
            }
        )
    }

    func controller(
        installed: String? = "1",
        store: MHRemoteUpdateStore? = nil,
        now: @escaping @Sendable () -> Date = { .init(timeIntervalSinceReferenceDate: Limits.now) },
        fetch: @escaping @Sendable () async throws -> MHRemoteUpdateSchedule
    ) throws -> MHRemoteUpdateController {
        try .init(
            bundleIdentifier: "example.app",
            storefront: nil,
            policyLifetime: Limits.policyAge,
            publicationLifetime: Limits.publicationAge,
            store: store,
            currentVersion: { installed },
            now: now,
            fetchSchedule: { .init(value: try await fetch(), fetchedAt: now()) },
            publicVersion: { nil }
        )
    }
}
