import Foundation
import MHRemoteUpdate
import Testing

struct MHRemoteUpdateScheduleLookupTests {
    @Test
    func resolvesScheduledPolicyFromAnIndependentEndpoint() async throws {
        let session = session()
        defer {
            session.invalidateAndCancel()
        }
        let schedule = try await lookup(session, scenario: "policy.json")
        #expect(schedule.revision == 1)
        #expect(schedule.requirement?.minimumVersion == MHAppVersion("6"))
    }

    @Test(arguments: ["status", "nonHTTP", "decode", "offline", "cancelled"])
    func failuresNeverBecomeNoUpdate(_ scenario: String) async throws {
        let session = session()
        defer {
            session.invalidateAndCancel()
        }
        if scenario == "cancelled" {
            await #expect(throws: CancellationError.self) {
                try await lookup(session, scenario: scenario)
            }
        } else {
            await #expect(throws: (any Error).self) {
                try await lookup(session, scenario: scenario)
            }
        }
    }

    @Test
    func wrongAppAndInsecureEndpointsAreRejected() async throws {
        let session = session()
        defer {
            session.invalidateAndCancel()
        }
        let lookup = MHRemoteUpdateScheduleLookup(session: session)
        await #expect(throws: MHRemoteUpdateSchedule.Failure.identityMismatch) {
            try await lookup.schedule(
                from: #require(URL(string: "https://example.com/update-policy/policy.json")),
                bundleIdentifier: "other.app"
            )
        }
        await #expect(throws: MHRemoteUpdateScheduleLookup.Failure.invalidRequest) {
            try await lookup.schedule(
                from: #require(URL(string: "http://example.com/policy.json")), bundleIdentifier: "example.app"
            )
        }
    }

    private func lookup(_ session: URLSession, scenario: String) async throws -> MHRemoteUpdateSchedule {
        try await MHRemoteUpdateScheduleLookup(session: session).schedule(
            from: #require(URL(string: "https://example.com/update-policy/\(scenario)")),
            bundleIdentifier: "example.app"
        )
    }

    private func session() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ScheduleURLProtocol.self]
        return .init(configuration: configuration)
    }
}
