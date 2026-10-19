import Foundation
import MHRemoteUpdate
import Testing

struct MHRemoteUpdateScheduleCodingTests {
    private typealias Fixture = RemoteUpdateTestSupport

    @Test
    func standardCodableAndConvenienceMethodsUseOneWireFormatIncludingDates() throws {
        let policy = try makePolicy(minimum: "2", activationDay: 1, endDay: 2)
        let standard = try JSONEncoder().encode(policy)
        #expect(try MHRemoteUpdateSchedule.decode(standard) == policy)
        #expect(try JSONDecoder().decode(MHRemoteUpdateSchedule.self, from: policy.encoded()) == policy)
        let object = try JSONSerialization.jsonObject(with: standard)
        let convenience = try JSONSerialization.jsonObject(with: policy.encoded())
        #expect(try JSONSerialization.data(withJSONObject: object, options: .sortedKeys)
                    == JSONSerialization.data(withJSONObject: convenience, options: .sortedKeys))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        #expect(try decoder.decode(MHRemoteUpdateSchedule.self, from: standard) == policy)
    }

    @Test(arguments: [#""schemaVersion":2,"#, #""schemaVersion":null,"#, #""schemaVersion":"1","#])
    func unsupportedOrInvalidFeatureFormatIsRejectedIndependently(_ field: String) {
        let document = Data("""
            {"schemaVersion":1,"bundleIdentifier":"example.app","features":{
            "remoteUpdate":{\(field)"revision":1,"requirement":null}}}
            """.utf8)
        #expect(throws: (any Error).self) {
            try MHRemoteUpdateSchedule.decode(document)
        }
    }

    @Test
    func priorCacheFormatRetainsItsOriginalObservationWithoutMigrationOrRenewal() throws {
        let data = Data(#"""
            {"schedule":{"schemaVersion":1,"bundleIdentifier":"example.app","revision":2,
            "requirement":{"minimumVersion":"2","effectiveAt":0}},
            "observation":{"fetchedAt":10,"validUntil":100},
            "publication":{"version":"2","checkedAt":10,"validUntil":50}}
        """#.utf8)
        let cached = try JSONDecoder().decode(MHRemoteUpdateSnapshot.self, from: data)
        #expect(cached.schedule.revision == 2)
        #expect(cached.observation.fetchedAt == Date(timeIntervalSinceReferenceDate: 10))
        #expect(try JSONDecoder().decode(
            MHRemoteUpdateSnapshot.self, from: JSONEncoder().encode(cached)
        ) == cached)
        let installedVersion = try #require(MHAppVersion("1"))
        #expect(cached.evaluate(
            currentVersion: installedVersion,
            now: .init(timeIntervalSinceReferenceDate: 20),
            maximumPolicyAge: 100,
            maximumPublicationAge: 100
        ) == .updateRequired)
    }

    @Test
    func minimalStaticCancellationRoundTripsWithoutPublisherTimestamps() throws {
        let document = Data(#"""
            {"schemaVersion":1,"bundleIdentifier":"example.app",
            "features":{"remoteUpdate":{"revision":1,"requirement":null}}}
        """#.utf8)
        let policy = try MHRemoteUpdateSchedule.decode(document)
        #expect(policy == (try makePolicy()))
        let encoded = try policy.encoded()
        let object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        #expect(object["issuedAt"] == nil)
        #expect(object["validUntil"] == nil)
        let features = try #require(object["features"] as? [String: Any])
        let update = try #require(features["remoteUpdate"] as? [String: Any])
        #expect(update["requirement"] is NSNull)
        #expect(try MHRemoteUpdateSchedule.decode(encoded) == policy)
    }

    @Test(arguments: [
        #""schemaVersion":2"#, #""schemaVersion":3"#, #""revision":0"#,
        #""bundleIdentifier":" app""#, #""requirement":{}"#,
        #""issuedAt":null"#, #""validUntil":null"#
    ])
    func malformedOrMixedSchemaDocumentsAreRejected(_ fragment: String) throws {
        var object = try #require(JSONSerialization.jsonObject(
            with: makePolicy().encoded()
        ) as? [String: Any])
        let replacement = try #require(JSONSerialization.jsonObject(
            with: Data("{\(fragment)}".utf8)
        ) as? [String: Any])
        if replacement["schemaVersion"] != nil || replacement["bundleIdentifier"] != nil {
            object.merge(replacement) { _, value in
                value
            }
        } else {
            var features = try #require(object["features"] as? [String: Any])
            var update = try #require(features["remoteUpdate"] as? [String: Any])
            update.merge(replacement) { _, value in
                value
            }
            features["remoteUpdate"] = update
            object["features"] = features
        }
        #expect(throws: (any Error).self) {
            try MHRemoteUpdateSchedule.decode(JSONSerialization.data(withJSONObject: object))
        }
    }

    @Test
    func missingRequirementIsNotCancellation() throws {
        let document = Data(#"""
            {"schemaVersion":1,"bundleIdentifier":"example.app","features":{"remoteUpdate":{"revision":1}}}
        """#.utf8)
        #expect(throws: MHRemoteUpdateSchedule.Failure.invalidDocument) {
            try MHRemoteUpdateSchedule.decode(document)
        }
    }

    @Test
    func legacyBoundedDocumentIsNotReinterpretedAsStaticConfiguration() {
        let document = Data(#"""
            {"schemaVersion":1,"bundleIdentifier":"example.app","revision":1,
            "issuedAt":"2026-10-01T00:00:00Z","validUntil":"2026-10-31T00:00:00Z","requirement":null}
        """#.utf8)
        #expect(throws: (any Error).self) {
            try MHRemoteUpdateSchedule.decode(document)
        }
    }

    @Test
    func unrelatedFeatureChangesDoNotChangeUpdatePolicyOrRevision() throws {
        let documents = [
            #"""
                {"schemaVersion":1,"bundleIdentifier":"example.app","features":{
                "remoteUpdate":{"revision":1,"requirement":null},"futureFeature":{"value":1}}}
            """#,
            #"""
                {"schemaVersion":1,"bundleIdentifier":"example.app","features":{
                "remoteUpdate":{"revision":1,"requirement":null},"futureFeature":"invalid for its own type"}}
            """#
        ]
        for document in documents {
            #expect(try MHRemoteUpdateSchedule.decode(Data(document.utf8)) == makePolicy())
        }
    }

    @Test(arguments: [#"{}"#, #"{"remoteUpdate":null}"#])
    func absentOrNullUpdateSectionIsNotCancellation(_ features: String) throws {
        let document = Data("""
            {"schemaVersion":1,"bundleIdentifier":"example.app","features":\(features)}
            """.utf8)
        #expect(throws: (any Error).self) {
            try MHRemoteUpdateSchedule.decode(document)
        }
    }

    @Test
    func activationDatesRetainWirePrecisionAndRejectCollapsedEnds() throws {
        let policy = try MHRemoteUpdateSchedule(
            bundleIdentifier: "example.app",
            revision: 1,
            requirement: .init(
                minimumVersion: #require(MHAppVersion("2")),
                effectiveAt: .init(timeIntervalSinceReferenceDate: 0.25),
                endsAt: .init(timeIntervalSinceReferenceDate: 10.75)
            )
        )
        #expect(try MHRemoteUpdateSchedule.decode(policy.encoded()) == policy)
        #expect(throws: MHRemoteUpdateSchedule.Failure.invalidDocument) {
            try MHRemoteUpdateSchedule(
                bundleIdentifier: "example.app",
                revision: 1,
                requirement: .init(
                    minimumVersion: #require(MHAppVersion("2")),
                    effectiveAt: .init(timeIntervalSinceReferenceDate: 0.25),
                    endsAt: .init(timeIntervalSinceReferenceDate: 0.75)
                )
            )
        }
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
}
