import Foundation
import MHRemoteUpdate
@testable import SurfaceAdapterConsumer
import Synchronization
import Testing

@MainActor
struct GuardedWriteTests {
    enum Caller: CaseIterable {
        case editor
        case intent

        var policy: MHRemoteUpdateOperationPolicy {
            self == .editor ? .allowWhenUnavailable : .requireConfirmation
        }
    }

    @Test(arguments: Caller.allCases)
    func activationWhileEditingBlocksBothSurfaces(_ caller: Caller) async throws {
        let clock = Mutex(10.0)
        let requests = Mutex(0)
        let version = try #require(MHAppVersion("2"))
        let schedule = try MHRemoteUpdateSchedule(
            bundleIdentifier: "example.journal",
            revision: 1,
            requirement: .init(minimumVersion: version, effectiveAt: .init(timeIntervalSinceReferenceDate: 20))
        )
        let controller = try MHRemoteUpdateController(
            bundleIdentifier: "example.journal",
            storefront: nil,
            policyLifetime: 100,
            publicationLifetime: 100,
            store: nil,
            currentVersion: { "1" },
            now: { Date(timeIntervalSinceReferenceDate: clock.withLock { $0 }) },
            fetchSchedule: {
                requests.withLock { $0 += 1 }
                return .init(value: schedule, fetchedAt: Date(timeIntervalSinceReferenceDate: clock.withLock { $0 }))
            },
            publicVersion: { version }
        )
        let operations = JournalWriteOperations(updates: .init(controller: controller))
        try await operations.becameActive()
        #expect(operations.updates.evaluation?.decision == .notRequired)
        clock.withLock { $0 = 20 }
        await #expect(throws: MHRemoteUpdateOperationError.updateRequired) {
            try await operations.save(policy: caller.policy) {
                Issue.record("A blocked caller wrote data")
            } afterSuccess: {
                Issue.record("A blocked caller reported success")
            }
        }
        #expect(operations.updates.evaluation?.decision == .updateRequired)
        #expect(requests.withLock { $0 } == 1)
    }

    @Test
    func retryReplacesUnavailableEvidenceAndEditsNeverFetch() async throws {
        let requests = Mutex(0)
        let controller = try MHRemoteUpdateController(
            bundleIdentifier: "example.journal",
            storefront: nil,
            policyLifetime: 100,
            publicationLifetime: 100,
            store: nil,
            currentVersion: { "1" },
            fetchSchedule: {
                let count = requests.withLock { count in
                    count += 1
                    return count
                }
                guard count > 1 else {
                    throw URLError(.notConnectedToInternet)
                }
                return .init(
                    value: try .init(bundleIdentifier: "example.journal", revision: 1, requirement: nil),
                    fetchedAt: .now
                )
            },
            publicVersion: { nil }
        )
        let operations = JournalWriteOperations(updates: .init(controller: controller))
        try await operations.becameActive()
        #expect(operations.updates.evaluation?.refreshError != nil)
        await #expect(throws: MHRemoteUpdateOperationError.policyUnavailable) {
            try await operations.save(policy: .requireConfirmation) { Issue.record("Unavailable") } afterSuccess: {
                Issue.record("Unexpected effect")
            }
        }
        var events = [String]()
        try await operations.save(policy: .allowWhenUnavailable) {
            events.append("offline")
        } afterSuccess: {
            events.append("success")
        }
        #expect(requests.withLock { $0 } == 1)
        try await operations.retry()
        try await operations.save(policy: .requireConfirmation) {
            events.append("confirmed")
        } afterSuccess: {
            events.append("success")
        }
        #expect(events == ["offline", "success", "confirmed", "success"])
        #expect(operations.updates.evaluation?.decision == .notRequired)
        #expect(requests.withLock { $0 } == 2)
    }

    @Test(arguments: Caller.allCases)
    func cancelledCallersNeverWriteOrReportSuccess(_ caller: Caller) async throws {
        let controller = try MHRemoteUpdateController(
            bundleIdentifier: "example.journal",
            storefront: nil,
            policyLifetime: 100,
            publicationLifetime: 100,
            store: nil,
            currentVersion: {
                withUnsafeCurrentTask { $0?.cancel() }
                return "1"
            },
            fetchSchedule: {
                Issue.record("A write tried to fetch")
                throw CancellationError()
            },
            publicVersion: { nil }
        )
        let operations = JournalWriteOperations(updates: .init(controller: controller))
        let task = Task {
            _ = try await operations.save(policy: caller.policy) {
                Issue.record("Cancelled mutation ran")
            } afterSuccess: {
                Issue.record("Cancelled success effect ran")
            }
        }
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(operations.updates.evaluation?.decision == .unavailable)
    }

    @Test
    func previewUsesNoController() async throws {
        let operations = JournalWriteOperations(updates: .preview())
        try await operations.becameActive()
        #expect(operations.updates.evaluation == nil)
        let value = try await operations.updates.perform(policy: .requireConfirmation) { "preview" }
        #expect(value == "preview")
    }
}
