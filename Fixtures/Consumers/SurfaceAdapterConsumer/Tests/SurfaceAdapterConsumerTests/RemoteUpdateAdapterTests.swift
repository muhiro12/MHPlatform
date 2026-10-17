import Foundation
import MHRemoteUpdate
@testable import SurfaceAdapterConsumer
import Testing

struct RemoteUpdateAdapterTests {
    private actor Recorder {
        private(set) var events: [String] = []

        func record(_ event: String) {
            events.append(event)
        }
    }

    @Test
    func appOwnedDocumentUsesSharedPolicyWithoutRuntimeProducts() async throws {
        let document = Data(#"""
            {"minimumVersion":"2","activatedAt":"2026-10-18T00:00:00Z","expiresAt":"2026-10-19T00:00:00Z"}
        """#.utf8)
        let now = try Date("2026-10-18T12:00:00Z", strategy: .iso8601)
        let decision = try await SurfaceAdapterConsumer.updateDecision(
            document: document, currentVersion: "1", now: now
        ) { MHAppVersion("2") }
        #expect(decision == .updateRequired)
    }

    @Test(arguments: [
        (MHRemoteUpdateDecision.updateRequired, MHRemoteUpdateOperationError.updateRequired),
        (.unavailable, .policyUnavailable)
    ])
    func blockedOperationPerformsNeitherMutationNorSuccessEffects(
        _ decision: MHRemoteUpdateDecision,
        _ expectedError: MHRemoteUpdateOperationError
    ) async {
        let recorder = Recorder()
        await #expect(throws: expectedError) {
            try await SurfaceAdapterConsumer.performProtectedOperation(
                decision: decision,
                whenUnavailable: .block,
                mutation: { await recorder.record("mutation") },
                afterSuccess: { await recorder.record("success") }
            )
        }
        #expect(await recorder.events.isEmpty)
    }

    @Test(arguments: [MHRemoteUpdateDecision.notRequired, .unavailable])
    func allowedOperationRunsMutationThenSuccessEffects(_ decision: MHRemoteUpdateDecision) async throws {
        let recorder = Recorder()
        try await SurfaceAdapterConsumer.performProtectedOperation(
            decision: decision,
            whenUnavailable: .allow,
            mutation: { await recorder.record("mutation") },
            afterSuccess: { await recorder.record("success") }
        )
        #expect(await recorder.events == ["mutation", "success"])
    }

    @Test
    func requiringUpdateBlocksEvenWhenUnavailablePolicyIsAllowed() async {
        await #expect(throws: MHRemoteUpdateOperationError.updateRequired) {
            try await SurfaceAdapterConsumer.performProtectedOperation(
                decision: .updateRequired,
                whenUnavailable: .allow,
                mutation: { Issue.record("Mutation must not run") },
                afterSuccess: { Issue.record("Success effects must not run") }
            )
        }
    }

    @Test
    func rejectedAppDocumentDoesNotBecomeAValidatedDecision() async throws {
        let document = Data(#"""
            {"minimumVersion":"2","activatedAt":"2026-10-18T00:00:00Z","expiresAt":"2026-10-25T00:00:00Z"}
        """#.utf8)
        let now = try Date("2026-10-18T12:00:00Z", strategy: .iso8601)
        await #expect(throws: SurfaceAdapterConsumer.UpdateFailure.self) {
            try await SurfaceAdapterConsumer.updateDecision(
                document: document,
                currentVersion: "1",
                now: now
            ) {
                Issue.record("Rejected document must not start a public-version lookup")
                return nil
            }
        }
    }

    @Test
    func mutationFailureDoesNotRunSuccessEffects() async {
        let recorder = Recorder()
        await #expect(throws: SurfaceAdapterConsumer.UpdateFailure.self) {
            try await SurfaceAdapterConsumer.performProtectedOperation(
                decision: .notRequired,
                whenUnavailable: .block,
                mutation: {
                    await recorder.record("mutation")
                    throw SurfaceAdapterConsumer.UpdateFailure.invalidPolicy
                },
                afterSuccess: { await recorder.record("success") }
            )
        }
        #expect(await recorder.events == ["mutation"])
    }
}
