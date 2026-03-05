import MHRouteExecution
import Testing

struct MHRouteExecutionTests {
    @Test
    func handle_applies_route_when_ready() async throws {
        let readiness = MHRouteExecutionReadinessFlag(initialValue: true)
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
            isReady: { readiness.value },
            executor: executor
        )

        let resolution = try await coordinator.handle(3)

        expectApplied(
            resolution,
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
    func handle_queues_route_when_not_ready() async throws {
        let readiness = MHRouteExecutionReadinessFlag(initialValue: false)
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
            isReady: { readiness.value },
            executor: executor
        )

        let queuedResolution = try await coordinator.handle(1)
        expectQueued(queuedResolution)
        #expect(await coordinator.hasPendingRoute)

        let pendingResolutionBeforeReady = try #require(
            try await coordinator.applyPendingIfNeeded()
        )
        expectQueued(pendingResolutionBeforeReady)

        readiness.set(true)

        let appliedResolution = try #require(
            try await coordinator.applyPendingIfNeeded()
        )
        expectApplied(
            appliedResolution,
            expected: 1
        )
        #expect(await coordinator.hasPendingRoute == false)
        #expect(await recorder.snapshot() == (resolved: [1], applied: [1]))
    }

    @Test
    func handle_overwrites_pending_route_with_latest_value() async throws {
        let readiness = MHRouteExecutionReadinessFlag(initialValue: false)
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
            isReady: { readiness.value },
            executor: executor
        )

        let firstResolution = try await coordinator.handle(1)
        let secondResolution = try await coordinator.handle(2)
        expectQueued(firstResolution)
        expectQueued(secondResolution)
        #expect(await coordinator.hasPendingRoute)

        readiness.set(true)

        let pendingResolution = try #require(
            try await coordinator.applyPendingIfNeeded()
        )
        expectApplied(
            pendingResolution,
            expected: 2
        )
        #expect(await recorder.snapshot() == (resolved: [2], applied: [2]))
        #expect(await coordinator.hasPendingRoute == false)
    }

    @Test
    func handle_queues_new_route_while_execution_is_running() async throws {
        let readiness = MHRouteExecutionReadinessFlag(initialValue: true)
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
            isReady: { readiness.value },
            executor: executor
        )

        let firstTask = Task {
            try await coordinator.handle(1)
        }

        await startedSignal.waitForStart()

        let queuedResolution = try await coordinator.handle(2)
        expectQueued(queuedResolution)
        #expect(await coordinator.hasPendingRoute)

        await gate.open()

        let firstResolution = try await firstTask.value
        expectApplied(
            firstResolution,
            expected: 1
        )

        let pendingResolution = try #require(
            try await coordinator.applyPendingIfNeeded()
        )
        expectApplied(
            pendingResolution,
            expected: 2
        )
        #expect(await recorder.snapshot() == (resolved: [1, 2], applied: [1, 2]))
        #expect(await coordinator.hasPendingRoute == false)
    }

    @Test
    func apply_pending_returns_nil_when_no_pending_route_exists() async throws {
        let readiness = MHRouteExecutionReadinessFlag(initialValue: true)
        let executor = MHRouteExecutor<Int, Int>(
            resolve: { route in
                route
            },
            apply: { _ in
                // Intentionally empty.
            }
        )
        let coordinator = MHRouteCoordinator(
            isReady: { readiness.value },
            executor: executor
        )

        let resolution = try await coordinator.applyPendingIfNeeded()
        if resolution != nil {
            Issue.record("Expected nil when no pending route exists.")
        }
    }

    @Test
    func apply_pending_keeps_pending_route_when_resolve_fails() async throws {
        let readiness = MHRouteExecutionReadinessFlag(initialValue: false)
        let executor = MHRouteExecutor<Int, Int>(
            resolve: { _ in
                throw MHRouteExecutionTestError.resolveFailed
            },
            apply: { _ in
                // Intentionally empty.
            }
        )
        let coordinator = MHRouteCoordinator(
            isReady: { readiness.value },
            executor: executor
        )

        let queuedResolution = try await coordinator.handle(1)
        expectQueued(queuedResolution)
        readiness.set(true)

        do {
            _ = try await coordinator.applyPendingIfNeeded()
            Issue.record("Expected resolve failure when applying pending route.")
        } catch {
            #expect(error is MHRouteExecutionTestError)
        }

        #expect(await coordinator.hasPendingRoute)
    }

    @Test
    func apply_pending_keeps_pending_route_when_apply_fails() async throws {
        let readiness = MHRouteExecutionReadinessFlag(initialValue: false)
        let executor = MHRouteExecutor<Int, Int>(
            resolve: { route in
                route
            },
            apply: { _ in
                throw MHRouteExecutionTestError.applyFailed
            }
        )
        let coordinator = MHRouteCoordinator(
            isReady: { readiness.value },
            executor: executor
        )

        let queuedResolution = try await coordinator.handle(1)
        expectQueued(queuedResolution)
        readiness.set(true)

        do {
            _ = try await coordinator.applyPendingIfNeeded()
            Issue.record("Expected apply failure when applying pending route.")
        } catch {
            #expect(error is MHRouteExecutionTestError)
        }

        #expect(await coordinator.hasPendingRoute)
    }

    @Test
    func clear_pending_route_removes_pending_value() async throws {
        let readiness = MHRouteExecutionReadinessFlag(initialValue: false)
        let executor = MHRouteExecutor<Int, Int>(
            resolve: { route in
                route
            },
            apply: { _ in
                // Intentionally empty.
            }
        )
        let coordinator = MHRouteCoordinator(
            isReady: { readiness.value },
            executor: executor
        )

        let queuedResolution = try await coordinator.handle(1)
        expectQueued(queuedResolution)
        #expect(await coordinator.hasPendingRoute)

        await coordinator.clearPendingRoute()

        #expect(await coordinator.hasPendingRoute == false)
        let resolution = try await coordinator.applyPendingIfNeeded()
        if resolution != nil {
            Issue.record("Expected nil after clearing pending route.")
        }
    }
}
