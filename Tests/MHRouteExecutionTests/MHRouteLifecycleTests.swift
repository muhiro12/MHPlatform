import Foundation
import MHDeepLinking
import MHLogging
import MHPlatformTesting
import MHRouteExecution
import Testing

struct MHRouteLifecycleTests {
    @Test
    func submit_logs_applied_outcome() async throws {
        let (logger, store) = makeLogger()
        let recorder = MHRouteExecutionRecorder<String>()
        let lifecycle = MHRouteLifecycle<Int>(
            logger: logger,
            initialReadiness: true,
            isDuplicate: ==
        )

        let outcome = try await lifecycle.submit(3) { resolvedRoute in
            await recorder.record("apply:\(resolvedRoute)")
        }

        expectApplied(
            outcome,
            expected: 3
        )
        #expect(await recorder.values() == ["apply:3"])
        let events = await store.events()
        #expect(events.map(\.level) == [.notice])
        #expect(events.map(\.message) == ["route applied"])
    }

    @Test
    func applyPendingIfReady_logs_queued_then_applied() async throws {
        let (logger, store) = makeLogger()
        let recorder = MHRouteExecutionRecorder<String>()
        let lifecycle = MHRouteLifecycle<Int>(
            logger: logger,
            initialReadiness: false,
            isDuplicate: ==
        )

        let queuedOutcome = try await lifecycle.submit(7) { resolvedRoute in
            await recorder.record("apply:\(resolvedRoute)")
        }
        let pendingWhileBlocked = try #require(
            try await lifecycle.applyPendingIfReady { resolvedRoute in
                await recorder.record("apply:\(resolvedRoute)")
            }
        )

        await lifecycle.setReadiness(true)

        let appliedOutcome = try #require(
            try await lifecycle.applyPendingIfReady { resolvedRoute in
                await recorder.record("apply:\(resolvedRoute)")
            }
        )

        expectQueued(queuedOutcome)
        expectQueued(pendingWhileBlocked)
        expectApplied(
            appliedOutcome,
            expected: 7
        )
        #expect(await recorder.values() == ["apply:7"])
        let events = await store.events()
        #expect(events.map(\.message) == [
            "route queued until execution becomes ready",
            "route queued until execution becomes ready",
            "route applied"
        ])
    }

    @Test
    func submit_logs_deduplicated_outcome() async throws {
        let (logger, store) = makeLogger()
        let lifecycle = MHRouteLifecycle<Int>(
            logger: logger,
            initialReadiness: false,
            isDuplicate: ==
        )

        let firstOutcome = try await lifecycle.submit(9) { _ in
            Issue.record("apply should not run while readiness is false")
        }
        let duplicateOutcome = try await lifecycle.submit(9) { _ in
            Issue.record("apply should not run for deduplicated routes")
        }

        expectQueued(firstOutcome)
        expectDeduplicated(duplicateOutcome)
        let events = await store.events()
        #expect(events.map(\.message) == [
            "route queued until execution becomes ready",
            "route deduplicated against pending route"
        ])
    }

    @Test
    func submit_url_logs_acceptance_and_applies_route() async throws {
        let (logger, store) = makeLogger()
        let recorder = MHRouteExecutionRecorder<String>()
        let lifecycle = MHRouteLifecycle<Int>(
            logger: logger,
            initialReadiness: true,
            isDuplicate: ==
        )
        guard let url = URL(string: "test://route/5") else {
            Issue.record("Expected test URL to be valid.")
            return
        }

        let outcome = try await lifecycle.submit(
            url,
            parse: { url in
                Int(url.lastPathComponent)
            },
            applyOnMainActor: { resolvedRoute in
                await recorder.record("apply:\(resolvedRoute)")
            }
        )

        let appliedOutcome = try #require(outcome)
        expectApplied(
            appliedOutcome,
            expected: 5
        )
        #expect(await recorder.values() == ["apply:5"])
        let events = await store.events()
        #expect(events.map(\.message) == [
            "accepted deep-link URL for route handling",
            "route applied"
        ])
    }

    @Test
    func submit_url_logs_rejection_without_applying_route() async throws {
        let (logger, store) = makeLogger()
        let recorder = MHRouteExecutionRecorder<String>()
        let lifecycle = MHRouteLifecycle<Int>(
            logger: logger,
            initialReadiness: true,
            isDuplicate: ==
        )
        guard let url = URL(string: "test://route/invalid") else {
            Issue.record("Expected test URL to be valid.")
            return
        }

        let outcome = try await lifecycle.submit(
            url,
            parse: { _ in
                nil
            },
            applyOnMainActor: { resolvedRoute in
                await recorder.record("apply:\(resolvedRoute)")
            }
        )

        if outcome != nil {
            Issue.record("Expected nil when URL parsing fails.")
        }
        #expect(await recorder.values().isEmpty)
        let events = await store.events()
        #expect(events.map(\.message) == [
            "ignored deep-link URL because parsing failed"
        ])
    }
}

private extension MHRouteLifecycleTests {
    enum TestConstants {
        static let maximumInMemoryEvents = 20
        static let maximumDiskBytes = 1_000
    }

    func makeLogger() -> (MHLogger, MHLogStore) {
        let store = MHLogStore(
            policy: .init(
                minimumLevel: .debug,
                persistsToDisk: false,
                maximumInMemoryEvents: TestConstants.maximumInMemoryEvents,
                maximumDiskBytes: TestConstants.maximumDiskBytes
            )
        )
        let logger = MHLogger(
            "Tests/MHRouteLifecycleTests.swift",
            store: store,
            subsystem: "tests.route"
        )
        return (logger, store)
    }

    func expectApplied(
        _ outcome: MHRouteExecutionOutcome<Int>,
        expected: Int
    ) {
        switch outcome {
        case .queued:
            Issue.record("Expected applied outcome, got queued.")
        case .applied(let resolvedRoute):
            #expect(resolvedRoute == expected)
        case .deduplicated:
            Issue.record("Expected applied outcome, got deduplicated.")
        }
    }

    func expectQueued(_ outcome: MHRouteExecutionOutcome<Int>) {
        switch outcome {
        case .queued:
            break
        case .applied(let resolvedRoute):
            Issue.record("Expected queued outcome, got applied(\(resolvedRoute)).")
        case .deduplicated:
            Issue.record("Expected queued outcome, got deduplicated.")
        }
    }

    func expectDeduplicated(_ outcome: MHRouteExecutionOutcome<Int>) {
        switch outcome {
        case .deduplicated:
            break
        case .queued:
            Issue.record("Expected deduplicated outcome, got queued.")
        case .applied(let resolvedRoute):
            Issue.record("Expected deduplicated outcome, got applied(\(resolvedRoute)).")
        }
    }
}
