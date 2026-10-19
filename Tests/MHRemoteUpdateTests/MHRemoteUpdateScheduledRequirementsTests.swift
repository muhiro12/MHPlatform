import Foundation
import MHRemoteUpdate
import Synchronization
import Testing

struct MHRemoteUpdateScheduledRequirementsTests: Sendable {
    private typealias Fixture = RemoteUpdateTestSupport

    @Test(arguments: [
        ("5", 0.0, MHRemoteUpdateDecision.updateRequired),
        ("6", 13.5, .notRequired),
        ("5", 13.5, .updateRequired),
        ("6", 14.0, .updateRequired),
        ("7", 14.0, .notRequired),
        ("6", 16.0, .updateRequired),
        ("6", 16.5, .notRequired),
        ("5", 16.5, .updateRequired)
    ])
    func baselineAndPlansAreEvaluatedTogether(
        _ installed: String, _ day: Double, _ expected: MHRemoteUpdateDecision
    ) throws {
        let schedule = try policy(plans: [requirement("7", from: 14, through: 16)])
        let installedVersion = try #require(MHAppVersion(installed))
        let publishedVersion = try #require(MHAppVersion("7"))
        let snapshot = MHRemoteUpdateSnapshot(
            schedule: schedule,
            storefront: nil,
            observation: .init(fetchedAt: Fixture.date(0), validUntil: Fixture.date(30)),
            publication: .init(
                version: publishedVersion,
                checkedAt: Fixture.date(0),
                validUntil: Fixture.date(30)
            )
        )
        #expect(snapshot.evaluate(
            currentVersion: installedVersion,
            now: Fixture.date(day),
            maximumPolicyAge: 30 * Fixture.day,
            maximumPublicationAge: 30 * Fixture.day
        ) == expected)
    }

    @Test
    func announcingPostponingAndCancellingAPlanNeverRemovesTheBaseline() async throws {
        let clock = Fixture.Clock()
        let published = Mutex(try policy())
        let updates = try controller(clock: clock, installed: "5") { published.withLock { $0 } }
        #expect(try await updates.refresh() == .updateRequired)
        let announced = try policy(revision: 2, plans: [requirement("7", from: 14)])
        published.withLock { $0 = announced }
        #expect(try await updates.refresh() == .updateRequired)
        let postponed = try policy(revision: 3, plans: [requirement("7", from: 20)])
        published.withLock { $0 = postponed }
        #expect(try await updates.refresh() == .updateRequired)
        let cancelledPlan = try policy(revision: 4)
        published.withLock { $0 = cancelledPlan }
        #expect(try await updates.refresh() == .updateRequired)
        let cancelledAll = try MHRemoteUpdateSchedule(bundleIdentifier: "example.app", revision: 5, requirement: nil)
        published.withLock { $0 = cancelledAll }
        #expect(try await updates.refresh() == .notRequired)
    }

    @Test(arguments: ["6", "7"])
    func futurePublicationIsPrefetchedAndActiveFloorsUseOnlyTheMinimumCurrentlyRequired(
        _ publishedVersion: String
    ) async throws {
        let clock = Fixture.Clock()
        let schedule = try policy(plans: [requirement("7", from: 0.5)])
        let publicVersion = Mutex(try #require(MHAppVersion(publishedVersion)))
        let lookups = Mutex(0)
        let updates = try controller(clock: clock, installed: "6", fetch: { schedule }, publicVersion: {
            lookups.withLock { $0 += 1 }
            return publicVersion.withLock { $0 }
        })
        #expect(try await updates.refresh() == .notRequired)
        #expect(lookups.withLock { $0 } == 1)
        clock.set(day: 0.5)
        #expect(await updates.decision() == (publishedVersion == "7" ? .updateRequired : .unavailable))
        let released = try #require(MHAppVersion("7"))
        publicVersion.withLock { $0 = released }
        #expect(try await updates.refresh() == .updateRequired)
    }

    @Test
    func acceptedPlansAndBaselineSurviveRestartWithoutRenewingEvidence() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        let store = MHRemoteUpdateStore(fileURL: directory.appendingPathComponent("snapshot.json"))
        let clock = Fixture.Clock()
        let schedule = try policy(plans: [requirement("7", from: 0.5)])
        let first = try controller(clock: clock, installed: "5", store: store) { schedule }
        #expect(try await first.refresh() == .updateRequired)
        let restored = try controller(clock: clock, installed: "5", store: store) { throw Fixture.Failure.offline }
        try await restored.restore()
        #expect(await restored.decision() == .updateRequired)
        #expect(try store.load()?.schedule == schedule)
        clock.set(day: 0.5)
        #expect(await restored.decision() == .unavailable)
        clock.set(day: 30)
        #expect(await restored.decision() == .unavailable)
        await #expect(throws: Fixture.Failure.self) {
            try await restored.checkOperationAllowed()
        }
    }

    @Test
    func changingPlansStillRequiresAnImmutableHigherRevision() async throws {
        let clock = Fixture.Clock()
        let published = Mutex(try policy(plans: [requirement("7", from: 14)]))
        let updates = try controller(clock: clock, installed: "5") { published.withLock { $0 } }
        try await updates.refresh()
        let changed = try policy(plans: [requirement("7", from: 20)])
        published.withLock { $0 = changed }
        await #expect(throws: MHRemoteUpdateController.Failure.revisionConflict) {
            try await updates.refresh()
        }
        #expect(await updates.decision() == .updateRequired)
    }

    @Test
    func overlappingPlansUseTheStrictestActiveMinimumRegardlessOfArrayOrder() throws {
        let plans = try [requirement("7", from: 10), requirement("8", from: 5), requirement("5", from: 0)]
        let publishedVersion = try #require(MHAppVersion("7"))
        for orderedPlans in [plans, Array(plans.reversed())] {
            let snapshot = MHRemoteUpdateSnapshot(
                schedule: try policy(plans: orderedPlans),
                storefront: nil,
                observation: .init(fetchedAt: Fixture.date(0), validUntil: Fixture.date(30)),
                publication: .init(
                    version: publishedVersion,
                    checkedAt: Fixture.date(10),
                    validUntil: Fixture.date(11)
                )
            )
            #expect(snapshot.evaluate(
                currentVersion: publishedVersion,
                now: Fixture.date(10),
                maximumPolicyAge: 30 * Fixture.day,
                maximumPublicationAge: Fixture.day
            ) == .unavailable)
        }
    }

    @Test(arguments: ["null", "{}", #"[{"minimumVersion":"7","effectiveAt":"invalid"}]"#])
    func malformedPlansNeverBecomeCancellation(_ plans: String) throws {
        let data = Data("""
            {"schemaVersion":1,"bundleIdentifier":"example.app","features":{"remoteUpdate":{
            "revision":1,"requirement":null,"scheduledRequirements":\(plans)}}}
            """.utf8)
        #expect(throws: (any Error).self) {
            try MHRemoteUpdateSchedule.decode(data)
        }
    }

    @Test
    func newPoliciesRoundTripAndExistingOneRequirementDocumentsStillDecode() throws {
        let schedule = try policy(plans: [requirement("7", from: 14)])
        #expect(try MHRemoteUpdateSchedule.decode(schedule.encoded()) == schedule)
        let oldDocument = Data(#"""
            {"schemaVersion":1,"bundleIdentifier":"example.app","features":{
            "remoteUpdate":{"revision":1,"requirement":null}}}
        """#.utf8)
        let oldSchedule = try MHRemoteUpdateSchedule.decode(oldDocument)
        #expect(oldSchedule.scheduledRequirements.isEmpty)
        #expect(oldSchedule.requirement == nil)
        #expect(try JSONDecoder().decode(
            MHRemoteUpdateSchedule.self, from: JSONEncoder().encode(schedule)
        ) == schedule)
    }

    @Test
    func a118SnapshotKeepsItsOriginalObservationAndBaseline() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent("snapshot.json")
        try Data(#"""
            {"schedule":{"schemaVersion":1,"bundleIdentifier":"example.app","revision":1,
            "requirement":{"minimumVersion":"6","effectiveAt":0}},
            "observation":{"fetchedAt":0,"validUntil":2592000},"storefront":null,
            "publication":{"version":"6","checkedAt":0,"validUntil":86400}}
        """#.utf8).write(to: fileURL)
        let store = MHRemoteUpdateStore(fileURL: fileURL)
        let clock = Fixture.Clock()
        let restored = try controller(clock: clock, installed: "5", store: store) { throw Fixture.Failure.offline }
        try await restored.restore()
        #expect(await restored.decision() == .updateRequired)
        #expect(try store.load()?.schedule.scheduledRequirements.isEmpty == true)
        #expect(try store.load()?.observation.fetchedAt == Fixture.date(0))
    }
}

private extension MHRemoteUpdateScheduledRequirementsTests {
    func requirement(_ version: String, from day: Double, through end: Double? = nil) throws
    -> MHRemoteUpdateSchedule.Requirement {
        try .init(
            minimumVersion: #require(MHAppVersion(version)),
            effectiveAt: Fixture.date(day),
            endsAt: end.map(Fixture.date)
        )
    }

    func policy(revision: Int = 1, plans: [MHRemoteUpdateSchedule.Requirement] = []) throws
    -> MHRemoteUpdateSchedule {
        try .init(
            bundleIdentifier: "example.app",
            revision: revision,
            requirement: requirement("6", from: 0),
            scheduledRequirements: plans
        )
    }

    func controller(
        clock: RemoteUpdateTestSupport.Clock,
        installed: String,
        store: MHRemoteUpdateStore? = nil,
        fetch: @escaping @Sendable () async throws -> MHRemoteUpdateSchedule,
        publicVersion: @escaping @Sendable () async throws -> MHAppVersion? = { MHAppVersion("6") }
    ) throws -> MHRemoteUpdateController {
        try .init(
            bundleIdentifier: "example.app",
            storefront: nil,
            policyLifetime: MHRemoteUpdateController.Defaults.policyLifetime,
            publicationLifetime: MHRemoteUpdateController.Defaults.publicationLifetime,
            store: store,
            currentVersion: { installed },
            now: { clock.now() },
            fetchSchedule: { .init(value: try await fetch(), fetchedAt: clock.now()) },
            publicVersion: publicVersion
        )
    }
}
