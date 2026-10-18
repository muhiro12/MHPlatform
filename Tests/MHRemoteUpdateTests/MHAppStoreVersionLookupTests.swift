import Foundation
import MHRemoteUpdate
import Testing

struct MHAppStoreVersionLookupTests {
    @Test(arguments: ["success", "mixed"])
    func resolvesOnlyTheExpectedAppInTheRequestedStorefront(_ scenario: String) async throws {
        let session = makeSession(scenario)
        defer {
            session.invalidateAndCancel()
        }
        let version = try await lookup(session)
        #expect(version == MHAppVersion("2"))
    }

    @Test(arguments: ["empty", "appMismatch", "bundleMismatch"])
    func rejectsMissingOrMismatchedIdentity(_ scenario: String) async {
        let session = makeSession(scenario)
        defer {
            session.invalidateAndCancel()
        }
        await #expect(throws: MHAppStoreVersionLookup.Failure.identityMismatch) {
            try await lookup(session)
        }
    }

    @Test(arguments: ["decode", "missingFields"])
    func propagatesDecodingFailure(_ scenario: String) async {
        let session = makeSession(scenario)
        defer {
            session.invalidateAndCancel()
        }
        await #expect(throws: DecodingError.self) {
            try await lookup(session)
        }
    }

    @Test(arguments: [
        ("status", MHAppStoreVersionLookup.Failure.httpStatus(503)),
        ("nonHTTP", .invalidResponse), ("invalidVersion", .invalidVersion)
    ])
    func rejectsInvalidResponses(_ scenario: String, _ failure: MHAppStoreVersionLookup.Failure) async {
        let session = makeSession(scenario)
        defer {
            session.invalidateAndCancel()
        }
        await #expect(throws: failure) {
            try await lookup(session)
        }
    }

    @Test
    func transportFailureRemainsAvailableToTheApp() async {
        let session = makeSession("transport")
        defer {
            session.invalidateAndCancel()
        }
        do {
            _ = try await lookup(session)
            Issue.record("Expected a transport error")
        } catch let error as URLError {
            #expect(error.code == .notConnectedToInternet)
        } catch {
            Issue.record(error)
        }
    }

    @Test
    func urlSessionCancellationIsNotConvertedToAnUpdateDecision() async {
        let session = makeSession("cancelled")
        defer {
            session.invalidateAndCancel()
        }
        await #expect(throws: CancellationError.self) {
            try await lookup(session)
        }
    }

    @Test(arguments: [(0, "com.example.app", "jp"), (123, "", "jp"), (123, " app", "jp"),
                      (123, "com.example.app", ""), (123, "com.example.app", "jpn"), (123, "com.example.app", "12")])
    func rejectsInvalidRequestBeforeNetworking(_ appID: Int, _ bundle: String, _ country: String) async {
        let session = makeSession("transport")
        defer {
            session.invalidateAndCancel()
        }
        await #expect(throws: MHAppStoreVersionLookup.Failure.invalidRequest) {
            try await MHAppStoreVersionLookup(session: session).version(
                appID: appID, bundleIdentifier: bundle, country: country
            )
        }
    }

    @Test
    func publicationLookupDoesNotRenewLocalHTTPMetadataAsFreshProof() async throws {
        let session = makeSession("publicationCache")
        defer {
            session.invalidateAndCancel()
        }
        let version = try await lookup(session)
        #expect(version == MHAppVersion("2"))
    }

    private func lookup(_ session: URLSession) async throws -> MHAppVersion {
        try await MHAppStoreVersionLookup(session: session).version(
            appID: 123, bundleIdentifier: "com.example.app", country: "jp"
        )
    }

    private func makeSession(_ scenario: String) -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [LookupURLProtocol.self]
        configuration.httpAdditionalHeaders = ["Scenario": scenario]
        return .init(configuration: configuration)
    }
}
