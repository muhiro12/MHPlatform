import MHRouteExecution
import Testing

struct MHRouteExecutionTests {
    @Test
    func submit_applies_route_when_ready() async throws {
        let recorder = MHRouteExecutionEventRecorder()
        let executor = MHRouteExecutor<Int, Int>(
            resolve: { route in
                await recorder.record("resolve:\(route)")
                return route * 10
            },
            apply: { outcome in
                await recorder.record("apply:\(outcome)")
            }
        )
        let coordinator = MHRouteCoordinator(
            initialReadiness: true,
            executor: executor
        )            { lhs, rhs in
                lhs == rhs
            }

        let outcome = try await coordinator.submit(3)

        expectApplied(
            outcome,
            expected: 30
        )
        #expect(
            await recorder.events() == [
                "resolve:3",
                "apply:30"
            ]
        )
        #expect(await coordinator.hasPendingRoute == false)
    }

    @Test
    func submit_queues_route_until_readiness_gate_opens() async throws {
        let recorder = MHRouteExecutionRouteRecorder()
        let executor = MHRouteExecutor<Int, Int>(
            resolve: { route in
                await recorder.recordResolvedRoute(route)
                return route
            },
            apply: { outcome in
                await recorder.recordAppliedOutcome(outcome)
            }
        )
        let coordinator = MHRouteCoordinator(
            initialReadiness: false,
            executor: executor
        )            { lhs, rhs in
                lhs == rhs
            }

        let queuedOutcome = try await coordinator.submit(1)
        expectQueued(queuedOutcome)

        let queuedPendingOutcome = try #require(
            try await coordinator.applyPendingIfReady()
        )
        expectQueued(queuedPendingOutcome)

        await coordinator.setReadiness(true)

        let appliedOutcome = try #require(
            try await coordinator.applyPendingIfReady()
        )
        expectApplied(
            appliedOutcome,
            expected: 1
        )

        #expect(await coordinator.hasPendingRoute == false)
        #expect(await recorder.snapshot() == (resolved: [1], applied: [1]))
    }

    @Test
    func submit_latest_wins_when_multiple_routes_are_queued() async throws {
        let recorder = MHRouteExecutionRouteRecorder()
        let executor = MHRouteExecutor<Int, Int>(
            resolve: { route in
                await recorder.recordResolvedRoute(route)
                return route
            },
            apply: { outcome in
                await recorder.recordAppliedOutcome(outcome)
            }
        )
        let coordinator = MHRouteCoordinator(
            initialReadiness: false,
            executor: executor
        )            { lhs, rhs in
                lhs == rhs
            }

        let firstOutcome = try await coordinator.submit(1)
        let secondOutcome = try await coordinator.submit(2)

        expectQueued(firstOutcome)
        expectQueued(secondOutcome)
        #expect(await coordinator.hasPendingRoute)

        await coordinator.setReadiness(true)

        let pendingOutcome = try #require(
            try await coordinator.applyPendingIfReady()
        )
        expectApplied(
            pendingOutcome,
            expected: 2
        )

        #expect(await recorder.snapshot() == (resolved: [2], applied: [2]))
    }

    @Test
    func submit_returns_deduplicated_for_duplicate_pending_route() async throws {
        let executor = MHRouteExecutor<Int, Int>(
            resolve: { route in
                route
            },
            apply: { _ in
                // Intentionally empty.
            }
        )
        let coordinator = MHRouteCoordinator(
            initialReadiness: false,
            executor: executor
        )            { lhs, rhs in
                lhs == rhs
            }

        let firstOutcome = try await coordinator.submit(1)
        let duplicateOutcome = try await coordinator.submit(1)

        expectQueued(firstOutcome)
        expectDeduplicated(duplicateOutcome)
    }

    @Test
    func submit_queues_new_route_while_execution_is_running() async throws {
        let recorder = MHRouteExecutionRouteRecorder()
        let startedSignal = MHRouteExecutionStartedSignal()
        let gate = MHRouteExecutionSuspensionGate()

        let executor = MHRouteExecutor<Int, Int>(
            resolve: { route in
                await recorder.recordResolvedRoute(route)
                if route == 1 {
                    await startedSignal.markStarted()
                    await gate.wait()
                }
                return route
            },
            apply: { outcome in
                await recorder.recordAppliedOutcome(outcome)
            }
        )
        let coordinator = MHRouteCoordinator(
            initialReadiness: true,
            executor: executor
        )            { lhs, rhs in
                lhs == rhs
            }

        let firstTask = Task {
            try await coordinator.submit(1)
        }

        await startedSignal.waitForStart()

        let queuedOutcome = try await coordinator.submit(2)
        expectQueued(queuedOutcome)
        #expect(await coordinator.hasPendingRoute)

        await gate.open()

        let firstOutcome = try await firstTask.value
        expectApplied(
            firstOutcome,
            expected: 1
        )

        let pendingOutcome = try #require(
            try await coordinator.applyPendingIfReady()
        )
        expectApplied(
            pendingOutcome,
            expected: 2
        )

        #expect(await recorder.snapshot() == (resolved: [1, 2], applied: [1, 2]))
        #expect(await coordinator.hasPendingRoute == false)
    }

    @Test
    func apply_pending_returns_nil_when_no_pending_route_exists() async throws {
        let executor = MHRouteExecutor<Int, Int>(
            resolve: { route in
                route
            },
            apply: { _ in
                // Intentionally empty.
            }
        )
        let coordinator = MHRouteCoordinator(
            initialReadiness: true,
            executor: executor
        )            { lhs, rhs in
                lhs == rhs
            }

        let outcome = try await coordinator.applyPendingIfReady()
        if outcome != nil {
            Issue.record("Expected nil when no pending route exists.")
        }
    }

    @Test
    func apply_pending_keeps_pending_route_when_execute_fails() async throws {
        let executor = MHRouteExecutor<Int, Int>(
            resolve: { _ in
                throw MHRouteExecutionTestError.resolveFailed
            },
            apply: { _ in
                // Intentionally empty.
            }
        )
        let coordinator = MHRouteCoordinator(
            initialReadiness: false,
            executor: executor
        )            { lhs, rhs in
                lhs == rhs
            }

        let queuedOutcome = try await coordinator.submit(1)
        expectQueued(queuedOutcome)
        await coordinator.setReadiness(true)

        do {
            _ = try await coordinator.applyPendingIfReady()
            Issue.record("Expected resolve failure when applying pending route.")
        } catch {
            #expect(error is MHRouteExecutionTestError)
        }

        #expect(await coordinator.hasPendingRoute)
    }

    @Test
    func clear_pending_route_removes_pending_value() async throws {
        let executor = MHRouteExecutor<Int, Int>(
            resolve: { route in
                route
            },
            apply: { _ in
                // Intentionally empty.
            }
        )
        let coordinator = MHRouteCoordinator(
            initialReadiness: false,
            executor: executor
        )            { lhs, rhs in
                lhs == rhs
            }

        let queuedOutcome = try await coordinator.submit(1)
        expectQueued(queuedOutcome)
        #expect(await coordinator.hasPendingRoute)

        await coordinator.clearPendingRoute()

        #expect(await coordinator.hasPendingRoute == false)
        let pendingOutcome = try await coordinator.applyPendingIfReady()
        if pendingOutcome != nil {
            Issue.record("Expected nil after clearing pending route.")
        }
    }
}
