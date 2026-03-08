import MHMutationFlow
import Testing

struct MHMutationWorkflowEventCallbackTests {
    private final class AttemptState: @unchecked Sendable {
        private var value = 0

        func nextAttempt() -> Int {
            value += 1
            return value
        }
    }

    private enum MutationTestError: Error {
        case operationFailed
        case sideEffectFailed
    }

    @Test
    func runThrowing_onEvent_maps_success_to_result_value() async throws {
        let recorder = MHMutationEventTraceRecorder<String>(
            traceBuilder: Self.trace
        )

        // `runThrowing` takes multiple closure arguments, so named closures are
        // clearer here than forcing trailing-closure syntax.
        // swiftlint:disable trailing_closure
        let result = try await MHMutationWorkflow.runThrowing(
            name: "saveProjectedDraft",
            operation: { () -> MHMutationProjection<Bool, String> in
                .init(
                    adapterValue: true,
                    resultValue: "saved"
                )
            },
            adapter: MHMutationAdapter<Bool> { shouldRunFollowUp in
                if shouldRunFollowUp {
                    return [
                        .init(name: "syncNotifications") {
                            // Intentionally empty.
                        }
                    ]
                }

                return []
            },
            projection: .keyPaths(
                adapterValue: \MHMutationProjection<Bool, String>.adapterValue,
                resultValue: \MHMutationProjection<Bool, String>.resultValue
            ),
            onEvent: { event in
                recorder.record(event)
            }
        )
        // swiftlint:enable trailing_closure

        #expect(result == "saved")
        #expect(recorder.all() == [
            "started:saveProjectedDraft:1",
            "progress:stepStarted:syncNotifications:0/1",
            "progress:stepSucceeded:syncNotifications:1/1",
            "succeeded:saved:1"
        ])
    }

    @Test
    func runThrowing_onEvent_reports_retry_sequence_once() async throws {
        let state = AttemptState()
        let recorder = MHMutationEventTraceRecorder<String>(
            traceBuilder: Self.trace
        )

        let result = try await MHMutationWorkflow.runThrowing(
            name: "saveProjectedDraft",
            operation: { () -> MHMutationProjection<Bool, String> in
                let attempt = state.nextAttempt()

                if attempt == 1 {
                    throw MutationTestError.operationFailed
                }

                return .init(
                    adapterValue: false,
                    resultValue: "saved"
                )
            },
            adapter: MHMutationAdapter<Bool>.none,
            projection: .keyPaths(
                adapterValue: \MHMutationProjection<Bool, String>.adapterValue,
                resultValue: \MHMutationProjection<Bool, String>.resultValue
            ),
            onEvent: { event in
                recorder.record(event)
            },
            configuration: .init(
                retryPolicy: .init(
                    maximumAttempts: 2,
                    backoff: .immediate
                )
            )
        )

        #expect(result == "saved")
        #expect(recorder.all() == [
            "started:saveProjectedDraft:1",
            "failed:1:true",
            "progress:retryScheduled:2",
            "started:saveProjectedDraft:2",
            "succeeded:saved:2"
        ])
    }

    @Test
    func runThrowing_onEvent_reports_step_failure_once() async {
        let recorder = MHMutationEventTraceRecorder<String>(
            traceBuilder: Self.trace
        )

        await #expect(
            throws: MHMutationWorkflowError.step(
                name: "syncNotifications",
                description: "sideEffectFailed"
            )
        ) {
            // `runThrowing` takes multiple closure arguments, so named closures are
            // clearer here than forcing trailing-closure syntax.
            // swiftlint:disable trailing_closure
            try await MHMutationWorkflow.runThrowing(
                name: "saveProjectedDraft",
                operation: { () -> MHMutationProjection<Bool, String> in
                    .init(
                        adapterValue: true,
                        resultValue: "saved"
                    )
                },
                adapter: MHMutationAdapter<Bool>.fixed(
                    [
                        .init(name: "syncNotifications") {
                            throw MutationTestError.sideEffectFailed
                        }
                    ]
                ),
                projection: .keyPaths(
                    adapterValue: \MHMutationProjection<Bool, String>.adapterValue,
                    resultValue: \MHMutationProjection<Bool, String>.resultValue
                ),
                onEvent: { event in
                    recorder.record(event)
                }
            )
            // swiftlint:enable trailing_closure
        }

        #expect(recorder.all() == [
            "started:saveProjectedDraft:1",
            "progress:stepStarted:syncNotifications:0/1",
            "failed:1:false"
        ])
    }

    @Test
    func runThrowing_onEvent_reports_cancellation_once() async {
        let recorder = MHMutationEventTraceRecorder<String>(
            traceBuilder: Self.trace
        )

        await #expect(throws: CancellationError.self) {
            // `runThrowing` takes multiple closure arguments, so named closures are
            // clearer here than forcing trailing-closure syntax.
            // swiftlint:disable trailing_closure
            try await MHMutationWorkflow.runThrowing(
                name: "saveProjectedDraft",
                operation: { () throws -> String in
                    throw CancellationError()
                },
                adapter: MHMutationAdapter<String>.none,
                projection: .identity,
                onEvent: { event in
                    recorder.record(event)
                }
            )
            // swiftlint:enable trailing_closure
        }

        #expect(recorder.all() == [
            "started:saveProjectedDraft:1",
            "cancelled:1"
        ])
    }
}

private extension MHMutationWorkflowEventCallbackTests {
    private static func trace(_ event: MHMutationEvent<String>) -> String {
        switch event {
        case let .started(mutation, attempt):
            return "started:\(mutation):\(attempt)"
        case let .progress(progress):
            return progressTrace(progress)
        case let .succeeded(value, attempts, _):
            return "succeeded:\(value):\(attempts)"
        case let .failed(_, attempts, _, isRecoverable):
            return "failed:\(attempts):\(isRecoverable)"
        case let .cancelled(attempts, _):
            return "cancelled:\(attempts)"
        }
    }

    private static func progressTrace(_ progress: MHMutationProgress) -> String {
        switch progress {
        case let .retryScheduled(nextAttempt, _):
            return "progress:retryScheduled:\(nextAttempt)"
        case let .stepStarted(name, completedSteps, totalSteps):
            return "progress:stepStarted:\(name):\(completedSteps)/\(totalSteps)"
        case let .stepSucceeded(name, completedSteps, totalSteps):
            return "progress:stepSucceeded:\(name):\(completedSteps)/\(totalSteps)"
        }
    }
}
