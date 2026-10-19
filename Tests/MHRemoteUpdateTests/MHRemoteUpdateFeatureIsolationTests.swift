import Foundation
import MHRemoteUpdate
import Synchronization
import Testing

struct MHRemoteUpdateFeatureIsolationTests: Sendable {
    private struct Companion: Decodable, Sendable {
        let value: Int
    }

    private struct Features: Decodable, Sendable {
        let remoteUpdate: MHRemoteConfigSection<MHRemoteUpdateSchedule.Feature>
        let companion: MHRemoteConfigSection<Companion>
    }

    @Test
    func unsupportedUpdateFormatDoesNotInvalidateAReadableSibling() throws {
        let document = try MHRemoteConfigDocument<Features>.decode(Data(#"""
            {"schemaVersion":1,"bundleIdentifier":"example.app","features":{
            "remoteUpdate":{"schemaVersion":999,"revision":1,"requirement":null},
            "companion":{"value":42}}}
        """#.utf8))
        #expect(try document.features.companion.get().value == 42)
        #expect(throws: MHRemoteUpdateSchedule.Failure.unsupportedSchema) {
            try document.features.remoteUpdate.get()
        }
    }

    @Test
    func oneValidatedResponseKeepsUpdateProcessingIndependentOfAnInvalidSibling() async throws {
        let session = session()
        defer {
            session.invalidateAndCancel()
        }
        let response = try await configuration("invalid-companion", session: session)
        #expect(throws: (any Error).self) {
            try response.value.features.companion.get()
        }
        let selected = try response.map { document in
            try MHRemoteUpdateSchedule(
                bundleIdentifier: document.bundleIdentifier,
                feature: document.features.remoteUpdate.get()
            )
        }
        #expect(selected.fetchedAt == response.fetchedAt)
        #expect(selected.value.requirement?.minimumVersion == MHAppVersion("6"))
        let standardLookup = try await MHRemoteUpdateScheduleLookup(session: session).schedule(
            from: #require(URL(string: "https://example.com/invalid-companion")),
            bundleIdentifier: "example.app"
        )
        #expect(standardLookup.value == selected.value)
    }

    @Test(arguments: ["invalid-update", "missing-update"])
    func failedUpdateDoesNotDiscardTheSiblingOrRenewRetainedUpdateEvidence(_ scenario: String) async throws {
        let session = session()
        defer {
            session.invalidateAndCancel()
        }
        let good = try await configuration("invalid-companion", session: session)
        let response = Mutex(good)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        let store = MHRemoteUpdateStore(fileURL: directory.appendingPathComponent("snapshot.json"))
        let updates = try MHRemoteUpdateController(
            bundleIdentifier: "example.app",
            storefront: nil,
            policyLifetime: MHRemoteUpdateController.Defaults.policyLifetime,
            publicationLifetime: MHRemoteUpdateController.Defaults.publicationLifetime,
            store: store,
            currentVersion: { "5" },
            fetchSchedule: {
                try response.withLock { $0 }.map { document in
                    try MHRemoteUpdateSchedule(
                        bundleIdentifier: document.bundleIdentifier,
                        feature: document.features.remoteUpdate.get()
                    )
                }
            },
            publicVersion: { MHAppVersion("6") }
        )
        #expect(try await updates.refresh() == .updateRequired)
        let original = try #require(try store.load())
        #expect(original.observation.fetchedAt == good.fetchedAt)
        let bad = try await configuration(scenario, session: session)
        #expect(try bad.value.features.companion.get().value == 42)
        response.withLock { $0 = bad }
        await #expect(throws: (any Error).self) {
            try await updates.refresh()
        }
        #expect(try store.load() == original)
        #expect(await updates.decision() == .updateRequired)
    }

    @Test(arguments: ["status", "nonHTTP", "decode", "unsupported", "cancelled"])
    func transportEnvelopeAndCancellationFailuresStillRejectTheSharedRequest(_ scenario: String) async throws {
        let session = session()
        defer {
            session.invalidateAndCancel()
        }
        await #expect(throws: (any Error).self) {
            try await configuration(scenario, session: session)
        }
        await #expect(throws: MHRemoteConfigError.identityMismatch) {
            try await MHRemoteConfigClient(session: session).configuration(
                from: #require(URL(string: "https://example.com/invalid-companion")),
                bundleIdentifier: "other.app",
                features: Features.self
            )
        }
    }

    private func configuration(
        _ scenario: String, session: URLSession
    ) async throws -> MHRemoteConfigResponse<MHRemoteConfigDocument<Features>> {
        try await MHRemoteConfigClient(session: session).configuration(
            from: #require(URL(string: "https://example.com/\(scenario)")),
            bundleIdentifier: "example.app",
            features: Features.self
        )
    }

    private func session() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ScheduleURLProtocol.self]
        return .init(configuration: configuration)
    }
}
