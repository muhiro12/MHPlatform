import Foundation
import MHRemoteUpdate
import Testing

struct MHRemoteUpdateScheduleTests {
    @Test
    func wireFormatRoundTripsExplicitCancellationAndNormalizedVersions() throws {
        let schedule = try makeSchedule()
        #expect(try MHRemoteUpdateSchedule.decode(schedule.encoded()) == schedule)
        let cancellation = try makeSchedule(hasRequirement: false)
        let data = try cancellation.encoded()
        #expect(String(data: data, encoding: .utf8)?.contains("\"requirement\" : null") == true)
        #expect(try MHRemoteUpdateSchedule.decode(data).requirement == nil)
        #expect(try JSONDecoder().decode(MHAppVersion.self, from: Data("\"06.0\"".utf8)).description == "6.0.0")
        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(MHAppVersion.self, from: Data("\"6-beta\"".utf8))
        }
    }

    @Test(arguments: [
        "\"schemaVersion\":2", "\"revision\":0", "\"bundleIdentifier\":\" \"",
        "\"validUntil\":\"2001-01-01T00:00:00Z\"", "\"requirement\":{}"
    ])
    func malformedWireDocumentsAreRejected(_ replacement: String) throws {
        let data = try makeSchedule(hasRequirement: false).encoded()
        var document = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let fragment = try #require(JSONSerialization.jsonObject(with: Data("{\(replacement)}".utf8)) as? [String: Any])
        document.merge(fragment) { _, replacementValue in
            replacementValue
        }
        #expect(throws: (any Error).self) {
            try MHRemoteUpdateSchedule.decode(JSONSerialization.data(withJSONObject: document))
        }
        document.removeValue(forKey: "requirement")
        #expect(throws: (any Error).self) {
            try MHRemoteUpdateSchedule.decode(JSONSerialization.data(withJSONObject: document))
        }
    }

    @Test
    func scheduledEvidenceIsReevaluatedAcrossActivationPublicationAndExpiry() throws {
        let schedule = try makeSchedule()
        let unconfirmed = MHRemoteUpdateSnapshot(schedule: schedule, storefront: "jp", publication: nil)
        #expect(unconfirmed.evaluate(
            currentVersion: try version("5"), now: date(9), maximumValidity: 30, maximumPublicationAge: 30
        ) == .notRequired)
        #expect(unconfirmed.evaluate(
            currentVersion: try version("5"), now: date(10), maximumValidity: 30, maximumPublicationAge: 30
        ) == .unavailable)
        let confirmed = MHRemoteUpdateSnapshot(schedule: schedule, storefront: "jp", publication: .init(
            version: try version("6"), checkedAt: date(8), validUntil: date(18)
        ))
        #expect(confirmed.evaluate(
            currentVersion: try version("5"), now: date(10), maximumValidity: 30, maximumPublicationAge: 30
        ) == .updateRequired)
        #expect(confirmed.evaluate(
            currentVersion: try version("6"), now: date(10), maximumValidity: 30, maximumPublicationAge: 30
        ) == .notRequired)
        #expect(confirmed.evaluate(
            currentVersion: try version("5"), now: date(18), maximumValidity: 30, maximumPublicationAge: 30
        ) == .unavailable)
        #expect(confirmed.evaluate(
            currentVersion: try version("5"), now: date(20), maximumValidity: 30, maximumPublicationAge: 30
        ) == .unavailable)
    }

    @Test
    func unpublishedMinimumAndExcessiveOrInvalidEvidenceAreUnavailable() throws {
        let schedule = try makeSchedule()
        let snapshot = MHRemoteUpdateSnapshot(schedule: schedule, storefront: "jp", publication: .init(
            version: try version("5"), checkedAt: date(8), validUntil: date(19)
        ))
        #expect(snapshot.evaluate(
            currentVersion: try version("5"), now: date(10), maximumValidity: 30, maximumPublicationAge: 30
        ) == .unavailable)
        #expect(snapshot.evaluate(
            currentVersion: try version("5"), now: date(10), maximumValidity: 5, maximumPublicationAge: 30
        ) == .unavailable)
        #expect(snapshot.evaluate(
            currentVersion: try version("5"), now: date(-1), maximumValidity: 30, maximumPublicationAge: 30
        ) == .unavailable)
        #expect(snapshot.evaluate(
            currentVersion: try version("5"), now: date(.nan), maximumValidity: 30, maximumPublicationAge: 30
        ) == .unavailable)
    }

    @Test
    func restoredEvidenceRespectsAShorterPublicationLifetime() throws {
        let snapshot = MHRemoteUpdateSnapshot(schedule: try makeSchedule(), storefront: "jp", publication: .init(
            version: try version("6"), checkedAt: date(8), validUntil: date(19)
        ))
        #expect(snapshot.evaluate(
            currentVersion: try version("5"), now: date(10), maximumValidity: 30, maximumPublicationAge: 2
        ) == .unavailable)
    }

    @Test
    func endingRequirementIsDifferentFromExpiringEvidence() throws {
        let schedule = try makeSchedule(requirement: .init(
            minimumVersion: try version("6"), effectiveAt: date(10), endsAt: date(12)
        ))
        let snapshot = MHRemoteUpdateSnapshot(schedule: schedule, storefront: "jp", publication: nil)
        #expect(snapshot.evaluate(
            currentVersion: try version("5"), now: date(12), maximumValidity: 30, maximumPublicationAge: 30
        ) == .unavailable)
        #expect(snapshot.evaluate(
            currentVersion: try version("5"), now: date(13), maximumValidity: 30, maximumPublicationAge: 30
        ) == .notRequired)
        #expect(snapshot.evaluate(
            currentVersion: try version("5"), now: date(20), maximumValidity: 30, maximumPublicationAge: 30
        ) == .unavailable)
    }

    @Test
    func storeRestoresFutureScheduleAndPublicationFromDisk() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        let fileURL = directory.appendingPathComponent("policy.json")
        let store = MHRemoteUpdateStore(fileURL: fileURL)
        #expect(try store.load() == nil)
        let snapshot = MHRemoteUpdateSnapshot(schedule: try makeSchedule(), storefront: "jp", publication: .init(
            version: try version("6"), checkedAt: date(8), validUntil: date(19)
        ))
        try store.save(snapshot)
        let restored = try #require(try MHRemoteUpdateStore(fileURL: fileURL).load())
        #expect(restored == snapshot)
        #expect(restored.evaluate(
            currentVersion: try version("5"), now: date(10), maximumValidity: 30, maximumPublicationAge: 30
        ) == .updateRequired)
        try Data("corrupt".utf8).write(to: fileURL)
        #expect(throws: (any Error).self) {
            try store.load()
        }
    }

    private func makeSchedule(
        hasRequirement: Bool = true,
        requirement: MHRemoteUpdateSchedule.Requirement? = nil
    ) throws -> MHRemoteUpdateSchedule {
        let selected = try requirement ?? .init(minimumVersion: try version("6"), effectiveAt: date(10))
        return try .init(
            bundleIdentifier: "example.app",
            revision: 1,
            issuedAt: date(0),
            validUntil: date(20),
            requirement: hasRequirement ? selected : nil
        )
    }

    private func version(_ value: String) throws -> MHAppVersion {
        try #require(MHAppVersion(value))
    }

    private func date(_ seconds: Double) -> Date {
        .init(timeIntervalSinceReferenceDate: seconds)
    }
}
