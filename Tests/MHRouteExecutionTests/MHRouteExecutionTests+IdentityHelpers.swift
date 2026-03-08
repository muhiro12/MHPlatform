import MHPlatformTesting
import MHRouteExecution
import Testing

extension MHRouteExecutionTests {
    @Test
    func identity_executor_returns_route_without_stored_apply() async throws {
        let executor = MHRouteExecutor<Int, Int>.identity

        let outcome = try await executor.execute(3)

        #expect(outcome == 3)
    }

    @Test
    func identity_coordinator_applies_route_when_ready() async throws {
        let recorder = MHRouteExecutionRecorder<String>()
        let coordinator = MHRouteCoordinator<Int, Int>(
            initialReadiness: true
        ) { lhs, rhs in
            lhs == rhs
        }

        let outcome = try await coordinator.submit(3) { route in
            await recorder.record("override:\(route)")
        }

        expectApplied(
            outcome,
            expected: 3
        )
        #expect(await recorder.values() == ["override:3"])
        #expect(await coordinator.hasPendingRoute == false)
    }

    @Test
    func identity_coordinator_deduplicates_duplicate_pending_route() async throws {
        let coordinator = MHRouteCoordinator<Int, Int>(
            initialReadiness: false
        ) { lhs, rhs in
            lhs == rhs
        }

        let firstOutcome = try await coordinator.submit(1)
        let duplicateOutcome = try await coordinator.submit(1)

        expectQueued(firstOutcome)
        expectDeduplicated(duplicateOutcome)
    }

    @Test
    func identity_coordinator_keeps_pending_route_when_apply_override_fails() async throws {
        let coordinator = MHRouteCoordinator<Int, Int>(
            initialReadiness: false
        ) { lhs, rhs in
            lhs == rhs
        }

        let queuedOutcome = try await coordinator.submit(1)
        expectQueued(queuedOutcome)
        await coordinator.setReadiness(true)

        do {
            _ = try await coordinator.applyPendingIfReady { _ in
                throw MHRouteExecutionTestError.applyFailed
            }
            Issue.record("Expected apply failure when applying pending route.")
        } catch {
            #expect(error is MHRouteExecutionTestError)
        }

        #expect(await coordinator.hasPendingRoute)
    }
}
