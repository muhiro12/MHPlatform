import MHMutationFlow
import Testing

struct MHMutationRunnerEventCallbackTests {
    private actor AttemptState {
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
    func start_onEvent_matches_stream_order() async {
        let recorder = MHMutationEventTraceRecorder<String>(
            traceBuilder: Self.trace
        )

        let runHandle = MHMutationRunner.start(
            mutation: MHMutation(name: "saveDraft") {
                "saved"
            },
            afterSuccess: [
                .init(name: "reloadWidgets") {
                    // Intentionally empty.
                },
                .init(name: "syncNotifications") {
                    // Intentionally empty.
                }
            ]
        ) { event in
            recorder.record(event)
        }

        async let streamTraceTask = Self.collectTraces(from: runHandle.events)
        let outcome = await runHandle.outcome.value
        let streamTraces = await streamTraceTask

        switch outcome {
        case .succeeded:
            break
        case .failed, .cancelled:
            Issue.record("Expected success outcome.")
        }

        #expect(recorder.all() == streamTraces)
        #expect(streamTraces == [
            "started:saveDraft:1",
            "progress:stepStarted:reloadWidgets:0/2",
            "progress:stepSucceeded:reloadWidgets:1/2",
            "progress:stepStarted:syncNotifications:1/2",
            "progress:stepSucceeded:syncNotifications:2/2",
            "succeeded:1"
        ])
    }

    @Test
    func run_onEvent_reports_retry_sequence_once() async {
        let state = AttemptState()
        let recorder = MHMutationEventTraceRecorder<String>(
            traceBuilder: Self.trace
        )

        let outcome = await MHMutationRunner.run(
            mutation: MHMutation(name: "saveDraft") {
                let attempt = await state.nextAttempt()

                if attempt == 1 {
                    throw MutationTestError.operationFailed
                }

                return "saved"
            },
            retryPolicy: .init(
                maximumAttempts: 2,
                backoff: .immediate
            )
        ) { event in
            recorder.record(event)
        }

        switch outcome {
        case let .succeeded(value, attempts, completedSteps):
            #expect(value == "saved")
            #expect(attempts == 2)
            #expect(completedSteps.isEmpty)
        case .failed, .cancelled:
            Issue.record("Expected retry success outcome.")
        }

        #expect(recorder.all() == [
            "started:saveDraft:1",
            "failed:1:true",
            "progress:retryScheduled:2",
            "started:saveDraft:2",
            "succeeded:2"
        ])
    }

    @Test
    func run_onEvent_reports_step_failure_once() async {
        let recorder = MHMutationEventTraceRecorder<String>(
            traceBuilder: Self.trace
        )

        let outcome = await MHMutationRunner.run(
            mutation: MHMutation(name: "saveDraft") {
                "saved"
            },
            afterSuccess: [
                .init(name: "reloadWidgets") {
                    // Intentionally empty.
                },
                .init(name: "syncNotifications") {
                    throw MutationTestError.sideEffectFailed
                }
            ]
        ) { event in
            recorder.record(event)
        }

        switch outcome {
        case let .failed(failure, attempts, completedSteps, isRecoverable):
            #expect(attempts == 1)
            #expect(completedSteps == ["reloadWidgets"])
            #expect(isRecoverable == false)

            switch failure {
            case let .step(name, _):
                #expect(name == "syncNotifications")
            case .operation:
                Issue.record("Expected step failure.")
            }
        case .succeeded, .cancelled:
            Issue.record("Expected step failure outcome.")
        }

        #expect(recorder.all() == [
            "started:saveDraft:1",
            "progress:stepStarted:reloadWidgets:0/2",
            "progress:stepSucceeded:reloadWidgets:1/2",
            "progress:stepStarted:syncNotifications:1/2",
            "failed:1:false"
        ])
    }

    @Test
    func run_onEvent_reports_cancellation_once() async {
        let cancellationHandle = MHCancellationHandle()
        let recorder = MHMutationEventTraceRecorder<String>(
            traceBuilder: Self.trace
        )

        let outcome = await MHMutationRunner.run(
            mutation: MHMutation(name: "saveDraft") {
                "saved"
            },
            cancellationHandle: cancellationHandle,
            afterSuccess: [
                .init(name: "reloadWidgets") {
                    cancellationHandle.cancel()
                },
                .init(name: "syncNotifications") {
                    // Intentionally empty.
                }
            ]
        ) { event in
            recorder.record(event)
        }

        switch outcome {
        case let .cancelled(attempts, completedSteps):
            #expect(attempts == 1)
            #expect(completedSteps == ["reloadWidgets"])
        case .succeeded, .failed:
            Issue.record("Expected cancellation outcome.")
        }

        #expect(recorder.all() == [
            "started:saveDraft:1",
            "progress:stepStarted:reloadWidgets:0/2",
            "progress:stepSucceeded:reloadWidgets:1/2",
            "cancelled:1"
        ])
    }
}

private extension MHMutationRunnerEventCallbackTests {
    private static func collectTraces(
        from events: AsyncStream<MHMutationEvent<String>>
    ) async -> [String] {
        var traces = [String]()

        for await event in events {
            traces.append(trace(event))
        }

        return traces
    }

    private static func trace(_ event: MHMutationEvent<String>) -> String {
        switch event {
        case let .started(mutation, attempt):
            return "started:\(mutation):\(attempt)"
        case let .progress(progress):
            return progressTrace(progress)
        case let .succeeded(_, attempts, _):
            return "succeeded:\(attempts)"
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
