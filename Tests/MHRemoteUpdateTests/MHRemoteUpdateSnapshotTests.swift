import Foundation
import MHRemoteUpdate
import Testing

struct MHRemoteUpdateSnapshotTests {
    @Test
    func activationAndPublicationExpiryAreIndependentOfPolicyFreshness() throws {
        let unconfirmed = try snapshot()
        #expect(unconfirmed.evaluate(
            currentVersion: try version("5"), now: date(9), maximumPolicyAge: 30, maximumPublicationAge: 30
        ) == .notRequired)
        #expect(unconfirmed.evaluate(
            currentVersion: try version("5"), now: date(10), maximumPolicyAge: 30, maximumPublicationAge: 30
        ) == .unavailable)
        let confirmed = try snapshot(publication: .init(
            version: version("6"), checkedAt: date(8), validUntil: date(18)
        ))
        #expect(confirmed.evaluate(
            currentVersion: try version("5"), now: date(10), maximumPolicyAge: 30, maximumPublicationAge: 30
        ) == .updateRequired)
        #expect(confirmed.evaluate(
            currentVersion: try version("6"), now: date(10), maximumPolicyAge: 30, maximumPublicationAge: 30
        ) == .notRequired)
        #expect(confirmed.evaluate(
            currentVersion: try version("5"), now: date(18), maximumPolicyAge: 30, maximumPublicationAge: 30
        ) == .unavailable)
        #expect(confirmed.evaluate(
            currentVersion: try version("6"), now: date(20), maximumPolicyAge: 30, maximumPublicationAge: 30
        ) == .unavailable)
    }

    @Test
    func localLifetimesAndClockAreReappliedWhenEvaluatingRetainedEvidence() throws {
        let evidence = try snapshot(publication: .init(
            version: version("6"), checkedAt: date(8), validUntil: date(19)
        ))
        #expect(evidence.evaluate(
            currentVersion: try version("5"), now: date(10), maximumPolicyAge: 5, maximumPublicationAge: 30
        ) == .unavailable)
        #expect(evidence.evaluate(
            currentVersion: try version("5"), now: date(10), maximumPolicyAge: 30, maximumPublicationAge: 2
        ) == .unavailable)
        for instant in [-1.0, .nan, .infinity] {
            #expect(evidence.evaluate(
                currentVersion: try version("6"), now: date(instant), maximumPolicyAge: 30, maximumPublicationAge: 30
            ) == .unavailable)
        }
    }

    @Test
    func endingARequirementDoesNotExtendPolicyEvidence() throws {
        let evidence = try snapshot(endsAt: date(12))
        #expect(evidence.evaluate(
            currentVersion: try version("5"), now: date(12), maximumPolicyAge: 30, maximumPublicationAge: 30
        ) == .unavailable)
        #expect(evidence.evaluate(
            currentVersion: try version("5"), now: date(13), maximumPolicyAge: 30, maximumPublicationAge: 30
        ) == .notRequired)
        #expect(evidence.evaluate(
            currentVersion: try version("5"), now: date(20), maximumPolicyAge: 30, maximumPublicationAge: 30
        ) == .unavailable)
    }

    @Test
    func storeRoundTripsObservationWithoutRenewingItAndRejectsCorruption() throws {
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer {
            try? FileManager.default.removeItem(at: fileURL)
        }
        let store = MHRemoteUpdateStore(fileURL: fileURL)
        #expect(try store.load() == nil)
        let evidence = try snapshot()
        try store.save(evidence)
        #expect(try store.load() == evidence)
        try Data("corrupt".utf8).write(to: fileURL)
        #expect(throws: (any Error).self) {
            try store.load()
        }
    }

    private func snapshot(
        endsAt: Date? = nil,
        publication: MHRemoteUpdateSnapshot.Publication? = nil
    ) throws -> MHRemoteUpdateSnapshot {
        try .init(
            schedule: .init(
                bundleIdentifier: "example.app",
                revision: 1,
                requirement: .init(minimumVersion: version("6"), effectiveAt: date(10), endsAt: endsAt)
            ),
            storefront: "jp",
            observation: .init(fetchedAt: date(0), validUntil: date(20)),
            publication: publication
        )
    }

    private func version(_ value: String) throws -> MHAppVersion {
        try #require(MHAppVersion(value))
    }

    private func date(_ seconds: Double) -> Date {
        .init(timeIntervalSinceReferenceDate: seconds)
    }
}
