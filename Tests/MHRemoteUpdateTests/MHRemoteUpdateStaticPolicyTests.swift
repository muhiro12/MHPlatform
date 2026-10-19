import Foundation
import MHRemoteUpdate
import Testing

struct MHRemoteUpdateStaticPolicyTests {
    private typealias Fixture = StaticPolicyTestSupport

    @Test
    func minimalStaticCancellationRoundTripsWithoutPublisherTimestamps() throws {
        let document = Data(#"""
            {"schemaVersion":2,"bundleIdentifier":"example.app","revision":1,"requirement":null}
        """#.utf8)
        let policy = try MHRemoteUpdateStaticPolicy.decode(document)
        #expect(policy == (try makePolicy()))
        let encoded = try policy.encoded()
        let object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        #expect(object["issuedAt"] == nil)
        #expect(object["validUntil"] == nil)
        #expect(object["requirement"] is NSNull)
        #expect(try MHRemoteUpdateStaticPolicy.decode(encoded) == policy)
        #expect(throws: (any Error).self) {
            try MHRemoteUpdateSchedule.decode(encoded)
        }
    }

    @Test(arguments: [
        #""schemaVersion":1"#, #""schemaVersion":3"#, #""revision":0"#,
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
        object.merge(replacement) { _, value in
            value
        }
        #expect(throws: (any Error).self) {
            try MHRemoteUpdateStaticPolicy.decode(JSONSerialization.data(withJSONObject: object))
        }
    }

    @Test
    func missingRequirementIsNotCancellation() throws {
        let document = Data(#"{"schemaVersion":2,"bundleIdentifier":"example.app","revision":1}"#.utf8)
        #expect(throws: MHRemoteUpdateStaticPolicy.Failure.invalidDocument) {
            try MHRemoteUpdateStaticPolicy.decode(document)
        }
    }

    @Test
    func activationDatesRetainWirePrecisionAndRejectCollapsedEnds() throws {
        let policy = try MHRemoteUpdateStaticPolicy(
            bundleIdentifier: "example.app",
            revision: 1,
            requirement: .init(
                minimumVersion: #require(MHAppVersion("2")),
                effectiveAt: .init(timeIntervalSinceReferenceDate: 0.25),
                endsAt: .init(timeIntervalSinceReferenceDate: 10.75)
            )
        )
        #expect(try MHRemoteUpdateStaticPolicy.decode(policy.encoded()) == policy)
        #expect(throws: MHRemoteUpdateStaticPolicy.Failure.invalidDocument) {
            try MHRemoteUpdateStaticPolicy(
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
    ) throws -> MHRemoteUpdateStaticPolicy {
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
