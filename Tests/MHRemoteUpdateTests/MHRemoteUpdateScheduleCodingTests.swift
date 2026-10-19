import Foundation
import MHRemoteUpdate
import Testing

struct MHRemoteUpdateScheduleCodingTests {
    private typealias Fixture = RemoteUpdateTestSupport

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
