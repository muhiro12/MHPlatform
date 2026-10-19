import Foundation
import MHRemoteUpdate
import Testing

struct MHRemoteUpdateConcurrencyTests: Sendable {
    private actor SuspendedSchedule {
        private var response: CheckedContinuation<MHRemoteUpdateSchedule, Never>?
        private var observer: CheckedContinuation<Void, Never>?
        private var requested = false

        func fetch() async -> MHRemoteUpdateSchedule {
            await withCheckedContinuation { continuation in
                response = continuation
                requested = true
                observer?.resume()
                observer = nil
            }
        }

        func waitForRequest() async {
            guard requested == false else {
                return
            }
            await withCheckedContinuation { continuation in
                observer = continuation
            }
        }

        func complete(_ schedule: MHRemoteUpdateSchedule) {
            response?.resume(returning: schedule)
            response = nil
        }
    }

    private actor Responses {
        var calls = 0
        let suspended: SuspendedSchedule
        let cancellation: MHRemoteUpdateSchedule

        init(suspended: SuspendedSchedule, cancellation: MHRemoteUpdateSchedule) {
            self.suspended = suspended
            self.cancellation = cancellation
        }

        func fetch() async -> MHRemoteUpdateSchedule {
            calls += 1
            if calls == 1 {
                return await suspended.fetch()
            }
            return cancellation
        }
    }

    @Test
    func lateResponseCannotResurrectCancelledSchedule() async throws {
        let gate = SuspendedSchedule()
        let cancellation = try schedule(revision: 2, requirement: false)
        let responses = Responses(suspended: gate, cancellation: cancellation)
        let controller = try controller { await responses.fetch() }
        let first = Task { try await controller.refresh() }
        await gate.waitForRequest()
        #expect(try await controller.refresh() == .notRequired)
        await gate.complete(try schedule(revision: 1, requirement: true))
        await #expect(throws: MHRemoteUpdateController.Failure.superseded) {
            try await first.value
        }
        #expect(await controller.decision() == .notRequired)
        #expect(await controller.evaluation().refreshError == nil)
    }

    @Test
    func saveFailureRetainsCurrentEvidenceInMemoryAndRemainsObservable() async throws {
        let blockedParent = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try Data("not a directory".utf8).write(to: blockedParent)
        defer {
            try? FileManager.default.removeItem(at: blockedParent)
        }
        let store = MHRemoteUpdateStore(fileURL: blockedParent.appendingPathComponent("policy.json"))
        let controller = try controller(store: store) { try schedule(revision: 1, requirement: false) }
        await #expect(throws: (any Error).self) {
            try await controller.refresh()
        }
        #expect(await controller.decision() == .notRequired)
    }

    @Test
    func restoreRejectsEvidenceFromAnotherStorefront() async throws {
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer {
            try? FileManager.default.removeItem(at: fileURL)
        }
        let store = MHRemoteUpdateStore(fileURL: fileURL)
        try store.save(.init(
            schedule: schedule(revision: 1, requirement: false),
            storefront: "us",
            observation: .init(
                fetchedAt: .init(timeIntervalSinceReferenceDate: 0),
                validUntil: .init(timeIntervalSinceReferenceDate: 100)
            ),
            publication: nil
        ))
        let controller = try controller(store: store) { try schedule(revision: 1, requirement: false) }
        await #expect(throws: MHRemoteUpdateController.Failure.identityMismatch) {
            try await controller.restore()
        }
        #expect(await controller.decision() == .unavailable)
    }

    private func controller(
        store: MHRemoteUpdateStore? = nil,
        fetch: @escaping @Sendable () async throws -> MHRemoteUpdateSchedule
    ) throws -> MHRemoteUpdateController {
        let publication: @Sendable () async -> MHAppVersion? = { MHAppVersion("6") }
        return try .init(
            bundleIdentifier: "example.app",
            storefront: "jp",
            policyLifetime: 100,
            publicationLifetime: 20,
            store: store,
            currentVersion: { "5" },
            now: { .init(timeIntervalSinceReferenceDate: 10) },
            fetchSchedule: {
                .init(value: try await fetch(), fetchedAt: .init(timeIntervalSinceReferenceDate: 10))
            },
            publicVersion: publication
        )
    }

    private func schedule(revision: Int, requirement: Bool) throws -> MHRemoteUpdateSchedule {
        try .init(
            bundleIdentifier: "example.app",
            revision: revision,
            requirement: requirement ? .init(
                minimumVersion: #require(MHAppVersion("6")), effectiveAt: .init(timeIntervalSinceReferenceDate: 10)
            ) : nil
        )
    }
}
