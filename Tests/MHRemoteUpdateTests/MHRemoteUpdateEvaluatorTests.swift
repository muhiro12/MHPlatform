import Foundation
import MHRemoteUpdate
import Synchronization
import Testing

struct MHRemoteUpdateEvaluatorTests {
    private enum ExpectedFailure: Error {
        case lookup
    }

    @Test(arguments: [nil, "bad version"])
    func unavailableInstalledVersionDoesNotFetch(_ installed: String?) async throws {
        let evaluator = MHRemoteUpdateEvaluator(currentVersion: { installed }, publicVersion: {
            throw ExpectedFailure.lookup
        })
        #expect(try await evaluator.evaluate(policy()) == .unavailable)
    }

    @Test
    func absentPolicyIsUnavailable() async throws {
        #expect(try await MHRemoteUpdateEvaluator { "1" }.evaluate(nil) == .unavailable)
    }

    @Test
    func skipsUnnecessaryPublicationRequests() async throws {
        let evaluator = MHRemoteUpdateEvaluator(currentVersion: { "2" }, publicVersion: {
            throw ExpectedFailure.lookup
        })
        #expect(try await evaluator.evaluate(policy()) == .notRequired)
        let unrestricted = MHRemoteUpdateEvaluator(currentVersion: { "1" }, publicVersion: {
            throw ExpectedFailure.lookup
        })
        #expect(try await unrestricted.evaluate(policy(requiresPublicVersion: false)) == .updateRequired)
    }

    @Test
    func publicationEvidenceCanBeRequiredMissingOrUnavailable() async throws {
        let evaluator = MHRemoteUpdateEvaluator(currentVersion: { "1" }, publicVersion: { MHAppVersion("2") })
        #expect(try await evaluator.evaluate(policy()) == .updateRequired)
        let missing = MHRemoteUpdateEvaluator { "1" }
        #expect(try await missing.evaluate(policy()) == .unavailable)
        let failing = MHRemoteUpdateEvaluator(currentVersion: { "1" }, publicVersion: {
            throw ExpectedFailure.lookup
        })
        await #expect(throws: ExpectedFailure.self) {
            try await failing.evaluate(policy())
        }
    }

    @Test
    func policyExpiringDuringLookupDoesNotRequireUpdate() async throws {
        let clock = Mutex(Date(timeIntervalSinceReferenceDate: 10))
        let window = try #require(MHUpdateActivationWindow(
            activatedAt: .init(timeIntervalSinceReferenceDate: 0),
            expiresAt: .init(timeIntervalSinceReferenceDate: 100),
            maximumDuration: 100
        ))
        let evaluator = MHRemoteUpdateEvaluator(
            currentVersion: { "1" },
            now: {
                clock.withLock { value in
                    value
                }
            },
            publicVersion: {
                clock.withLock { value in
                    value = .init(timeIntervalSinceReferenceDate: 101)
                }
                return MHAppVersion("2")
            })
        #expect(try await evaluator.evaluate(policy(window: window)) == .notRequired)
    }

    @Test
    func inactivePolicyAndInvalidClockDoNotFetch() async throws {
        let window = try #require(MHUpdateActivationWindow(
            activatedAt: .init(timeIntervalSinceReferenceDate: 100),
            expiresAt: .init(timeIntervalSinceReferenceDate: 200),
            maximumDuration: 100
        ))
        for instant in [0.0, 201.0, .nan] {
            let evaluator = MHRemoteUpdateEvaluator(
                currentVersion: { "1" },
                now: {
                    .init(timeIntervalSinceReferenceDate: instant)
                },
                publicVersion: {
                    throw ExpectedFailure.lookup
                })
            let expected: MHRemoteUpdateDecision = instant.isFinite ? .notRequired : .unavailable
            #expect(try await evaluator.evaluate(policy(window: window)) == expected)
        }
    }

    @Test
    func cancellationDuringLookupPropagates() async throws {
        let policy = try policy()
        let task = Task {
            let evaluator = MHRemoteUpdateEvaluator(currentVersion: { "1" }, publicVersion: {
                withUnsafeCurrentTask { task in
                    task?.cancel()
                }
                return MHAppVersion("2")
            })
            return try await evaluator.evaluate(policy)
        }
        await #expect(throws: CancellationError.self) {
            try await task.value
        }
        let cancelledLookup = MHRemoteUpdateEvaluator(currentVersion: { "1" }, publicVersion: {
            throw URLError(.cancelled)
        })
        await #expect(throws: CancellationError.self) {
            try await cancelledLookup.evaluate(policy)
        }
    }

    private func policy(
        requiresPublicVersion: Bool = true,
        window: MHUpdateActivationWindow? = nil
    ) throws -> MHRemoteUpdatePolicy {
        .init(
            minimumVersion: try #require(MHAppVersion("2")),
            activationWindow: window,
            requiresPublicVersion: requiresPublicVersion
        )
    }
}
