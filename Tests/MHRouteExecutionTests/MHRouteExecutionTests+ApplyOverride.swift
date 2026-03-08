import MHPlatformTesting
import MHRouteExecution
import Testing

extension MHRouteExecutionTests {
    @Test
    func submit_with_apply_override_applies_route_when_ready() async throws {
        let recorder = MHRouteExecutionRecorder<String>()
        let executor = MHRouteExecutor<Int, Int>(
            resolve: { route in
                await recorder.record("resolve:\(route)")
                return route * 10
            },
            apply: { outcome in
                await recorder.record("stored:\(outcome)")
            }
        )
        let coordinator = MHRouteCoordinator(
            executor: executor,
            initialReadiness: true
        ) { lhs, rhs in
            lhs == rhs
        }

        let outcome = try await coordinator.submit(3) { resolvedValue in
            await recorder.record("override:\(resolvedValue)")
        }

        expectApplied(
            outcome,
            expected: 30
        )
        #expect(
            await recorder.values() == [
                "resolve:3",
                "override:30"
            ]
        )
    }

    @Test
    func apply_pending_with_apply_override_uses_override_when_readiness_opens() async throws {
        let recorder = MHRouteExecutionRecorder<String>()
        let executor = MHRouteExecutor<Int, Int>(
            resolve: { route in
                await recorder.record("resolve:\(route)")
                return route
            },
            apply: { outcome in
                await recorder.record("stored:\(outcome)")
            }
        )
        let coordinator = MHRouteCoordinator(
            executor: executor,
            initialReadiness: false
        ) { lhs, rhs in
            lhs == rhs
        }

        let queuedOutcome = try await coordinator.submit(7)
        expectQueued(queuedOutcome)

        await coordinator.setReadiness(true)

        let appliedOutcome = try #require(
            try await coordinator.applyPendingIfReady { resolvedValue in
                await recorder.record("override:\(resolvedValue)")
            }
        )
        expectApplied(
            appliedOutcome,
            expected: 7
        )
        #expect(
            await recorder.values() == [
                "resolve:7",
                "override:7"
            ]
        )
    }

    @Test
    func submit_with_apply_override_keeps_duplicate_pending_route_deduplicated() async throws {
        let recorder = MHRouteExecutionRecorder<String>()
        let executor = MHRouteExecutor<Int, Int>(
            resolve: { route in
                await recorder.record("resolve:\(route)")
                return route
            },
            apply: { outcome in
                await recorder.record("stored:\(outcome)")
            }
        )
        let coordinator = MHRouteCoordinator(
            executor: executor,
            initialReadiness: false
        ) { lhs, rhs in
            lhs == rhs
        }

        let firstOutcome = try await coordinator.submit(9)
        let duplicateOutcome = try await coordinator.submit(9) { resolvedValue in
            await recorder.record("override:\(resolvedValue)")
        }

        expectQueued(firstOutcome)
        expectDeduplicated(duplicateOutcome)

        await coordinator.setReadiness(true)

        let appliedOutcome = try #require(
            try await coordinator.applyPendingIfReady { resolvedValue in
                await recorder.record("override:\(resolvedValue)")
            }
        )
        expectApplied(
            appliedOutcome,
            expected: 9
        )
        #expect(
            await recorder.values() == [
                "resolve:9",
                "override:9"
            ]
        )
    }
}
