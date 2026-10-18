import Foundation
import MHRemoteUpdate
@testable import SurfaceAdapterConsumer
import Testing

struct ScheduledUpdateAdapterTests: Sendable {
    private enum ExpectedFailure: Error {
        case offline
    }

    private actor Recorder {
        private(set) var events: [String] = []

        func record(_ value: String) {
            events.append(value)
        }
    }

    @Test
    func offlineBrowseContinuesWithoutFetching() async throws {
        let recorder = Recorder()
        let controller = try controller {
            Issue.record("Browsing with unknown policy must not request the network")
            throw ExpectedFailure.offline
        }
        try await perform(.browse, updates: controller, recorder: recorder)
        #expect(await recorder.events == ["operation", "success"])
    }

    @Test
    func offlineSavePerformsNeitherMutationNorSuccessEffects() async throws {
        let recorder = Recorder()
        let controller = try controller {
            await recorder.record("fetch")
            throw ExpectedFailure.offline
        }
        await #expect(throws: ExpectedFailure.self) {
            try await perform(.save, updates: controller, recorder: recorder)
        }
        #expect(await recorder.events == ["fetch"])
    }

    @Test
    func saveFetchesOnceThenContinuesOnlyWithConfirmedPermission() async throws {
        let recorder = Recorder()
        let controller = try controller {
            await recorder.record("fetch")
            return try document(requirement: false)
        }
        try await perform(.save, updates: controller, recorder: recorder)
        #expect(await recorder.events == ["fetch", "operation", "success"])
    }

    @Test(arguments: [SurfaceAdapterConsumer.ScheduledOperation.browse, .save])
    func knownRequiredStopsBothKindsOfOperation(_ operation: SurfaceAdapterConsumer.ScheduledOperation) async throws {
        let recorder = Recorder()
        let controller = try controller { try document(requirement: true) }
        try await controller.refresh()
        await #expect(throws: MHRemoteUpdateOperationError.updateRequired) {
            try await perform(operation, updates: controller, recorder: recorder)
        }
        #expect(await recorder.events.isEmpty)
    }

    @Test
    func unconfirmedPublicationDoesNotAllowSave() async throws {
        let recorder = Recorder()
        let lookup: @Sendable () async -> MHAppVersion? = { nil }
        let controller = try controller(fetch: { try document(requirement: true) }, publicVersion: lookup)
        await #expect(throws: MHRemoteUpdateOperationError.policyUnavailable) {
            try await perform(.save, updates: controller, recorder: recorder)
        }
        #expect(await recorder.events.isEmpty)
    }

    private func perform(
        _ operation: SurfaceAdapterConsumer.ScheduledOperation,
        updates: MHRemoteUpdateController,
        recorder: Recorder
    ) async throws {
        try await SurfaceAdapterConsumer.performScheduledOperation(
            operation,
            updates: updates,
            mutation: { await recorder.record("operation") },
            afterSuccess: { await recorder.record("success") }
        )
    }

    private func controller(
        fetch: @escaping @Sendable () async throws -> MHRemoteUpdateSchedule,
        publicVersion: @escaping @Sendable () async throws -> MHAppVersion? = { MHAppVersion("2") }
    ) throws -> MHRemoteUpdateController {
        try .init(
            bundleIdentifier: "example.app",
            storefront: "jp",
            maximumValidity: 100,
            publicationLifetime: 20,
            store: nil,
            currentVersion: { "1" },
            now: { .init(timeIntervalSinceReferenceDate: 10) },
            fetchSchedule: fetch,
            publicVersion: publicVersion
        )
    }

    private func document(requirement: Bool) throws -> MHRemoteUpdateSchedule {
        try .init(
            bundleIdentifier: "example.app",
            revision: 1,
            issuedAt: .init(timeIntervalSinceReferenceDate: 0),
            validUntil: .init(timeIntervalSinceReferenceDate: 100),
            requirement: requirement ? .init(
                minimumVersion: #require(MHAppVersion("2")), effectiveAt: .init(timeIntervalSinceReferenceDate: 0)
            ) : nil
        )
    }
}
