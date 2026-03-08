import Foundation
import MHMutationFlow
import Testing

struct MHMutationFlowTests {
    private actor AttemptState {
        private var value = 0

        func nextAttempt() -> Int {
            value += 1
            return value
        }

        func attempts() -> Int {
            value
        }
    }

    private actor DurationRecorder {
        private var values = [Duration]()

        func append(_ value: Duration) {
            values.append(value)
        }

        func all() -> [Duration] {
            values
        }
    }

    private enum MutationTestError: Error {
        case operationFailed
        case sideEffectFailed
    }

    @Test
    func succeeds_without_retry() async {
        let mutation = MHMutation<String>(
            name: "saveDraft"
        ) {
            "saved"
        }

        let outcome = await MHMutationRunner.run(
            mutation: mutation,
            afterSuccess: [
                .init(name: "reloadWidgets") {
                    // Intentionally empty.
                }
            ]
        )

        switch outcome {
        case let .succeeded(value, attempts, completedSteps):
            #expect(value == "saved")
            #expect(attempts == 1)
            #expect(completedSteps == ["reloadWidgets"])
        case .failed, .cancelled:
            Issue.record("Expected success outcome.")
        }
    }

    @Test
    func retries_with_injected_sleep_and_succeeds() async {
        let state = AttemptState()
        let durationRecorder = DurationRecorder()

        let mutation = MHMutation<String>(
            name: "saveDraft"
        ) {
            let attempt = await state.nextAttempt()
            if attempt == 1 {
                throw MutationTestError.operationFailed
            }
            return "saved"
        }

        // `sleep` is the second closure-shaped parameter, so Swift cannot
        // express this call with trailing-closure syntax only.
        // swiftlint:disable trailing_closure
        let outcome = await MHMutationRunner.run(
            mutation: mutation,
            retryPolicy: .init(
                maximumAttempts: 3,
                backoff: .exponential(
                    base: .milliseconds(10),
                    factor: 2,
                    maximumDelay: .milliseconds(40)
                )
            ),
            sleep: { duration in
            await durationRecorder.append(duration)
            }
        )
        // swiftlint:enable trailing_closure

        switch outcome {
        case let .succeeded(value, attempts, completedSteps):
            #expect(value == "saved")
            #expect(attempts == 2)
            #expect(completedSteps.isEmpty)
        case .failed, .cancelled:
            Issue.record("Expected success outcome.")
        }

        #expect(await state.attempts() == 2)
        #expect(await durationRecorder.all() == [.milliseconds(10)])
    }

    @Test
    func fails_after_retry_exhaustion() async {
        let mutation = MHMutation<String>(
            name: "saveDraft"
        ) {
            throw MutationTestError.operationFailed
        }

        let outcome = await MHMutationRunner.run(
            mutation: mutation,
            retryPolicy: .init(
                maximumAttempts: 3,
                backoff: .immediate
            )
        )

        switch outcome {
        case let .failed(failure, attempts, completedSteps, isRecoverable):
            #expect(attempts == 3)
            #expect(completedSteps.isEmpty)
            #expect(isRecoverable == false)
            switch failure {
            case .operation(let errorDescription):
                #expect(errorDescription.contains("operationFailed"))
            case .step:
                Issue.record("Expected operation failure.")
            }
        case .succeeded, .cancelled:
            Issue.record("Expected failure outcome.")
        }
    }

    @Test
    func returns_cancelled_before_start() async {
        let cancellationHandle = MHCancellationHandle()
        cancellationHandle.cancel()

        let mutation = MHMutation<String>(
            name: "saveDraft"
        ) {
            "saved"
        }

        let outcome = await MHMutationRunner.run(
            mutation: mutation,
            cancellationHandle: cancellationHandle
        )

        switch outcome {
        case let .cancelled(attempts, completedSteps):
            #expect(attempts == 0)
            #expect(completedSteps.isEmpty)
        case .succeeded, .failed:
            Issue.record("Expected cancelled outcome.")
        }
    }

    @Test
    func returns_cancelled_between_side_effects() async {
        let cancellationHandle = MHCancellationHandle()

        let mutation = MHMutation<String>(
            name: "saveDraft"
        ) {
            "saved"
        }

        let outcome = await MHMutationRunner.run(
            mutation: mutation,
            cancellationHandle: cancellationHandle,
            afterSuccess: [
                .init(name: "reloadWidgets") {
                    cancellationHandle.cancel()
                },
                .init(name: "syncNotifications") {
                    // Intentionally empty.
                }
            ]
        )

        switch outcome {
        case let .cancelled(attempts, completedSteps):
            #expect(attempts == 1)
            #expect(completedSteps == ["reloadWidgets"])
        case .succeeded, .failed:
            Issue.record("Expected cancelled outcome.")
        }
    }

    @Test
    func emits_ordered_event_stream() async {
        let mutation = MHMutation<String>(
            name: "saveDraft"
        ) {
            "saved"
        }

        let runHandle = MHMutationRunner.start(
            mutation: mutation,
            afterSuccess: [
                .init(name: "reloadWidgets") {
                    // Intentionally empty.
                },
                .init(name: "syncNotifications") {
                    // Intentionally empty.
                }
            ]
        )

        async let eventTitlesTask = eventTitles(from: runHandle.events)
        let outcome = await runHandle.outcome.value
        let eventTitles = await eventTitlesTask

        switch outcome {
        case .succeeded:
            break
        case .failed, .cancelled:
            Issue.record("Expected success outcome.")
        }

        #expect(eventTitles == [
            "started:saveDraft:1",
            "progress:stepStarted:reloadWidgets:0/2",
            "progress:stepSucceeded:reloadWidgets:1/2",
            "progress:stepStarted:syncNotifications:1/2",
            "progress:stepSucceeded:syncNotifications:2/2",
            "succeeded:1"
        ])
    }

    @Test
    func reports_step_failure_without_retrying_operation() async {
        let state = AttemptState()

        let mutation = MHMutation<String>(
            name: "saveDraft"
        ) {
            _ = await state.nextAttempt()
            return "saved"
        }

        let outcome = await MHMutationRunner.run(
            mutation: mutation,
            retryPolicy: .init(
                maximumAttempts: 3,
                backoff: .immediate
            ),
            afterSuccess: [
                .init(name: "reloadWidgets") {
                    // Intentionally empty.
                },
                .init(name: "syncNotifications") {
                    throw MutationTestError.sideEffectFailed
                }
            ]
        )

        #expect(await state.attempts() == 1)

        switch outcome {
        case let .failed(failure, attempts, completedSteps, isRecoverable):
            #expect(attempts == 1)
            #expect(completedSteps == ["reloadWidgets"])
            #expect(isRecoverable == false)
            switch failure {
            case .operation:
                Issue.record("Expected step failure.")
            case let .step(name, errorDescription):
                #expect(name == "syncNotifications")
                #expect(errorDescription.contains("sideEffectFailed"))
            }
        case .succeeded, .cancelled:
            Issue.record("Expected failure outcome.")
        }
    }
}

private extension MHMutationFlowTests {
    func eventTitles(
        from events: AsyncStream<MHMutationEvent<String>>
    ) async -> [String] {
        var titles = [String]()

        for await event in events {
            switch event {
            case let .started(mutation, attempt):
                titles.append("started:\(mutation):\(attempt)")
            case .progress(let progress):
                titles.append(progressTitle(progress))
            case let .succeeded(_, attempts, _):
                titles.append("succeeded:\(attempts)")
            case let .failed(errorDescription, attempts, _, isRecoverable):
                titles.append(
                    "failed:\(attempts):\(isRecoverable):\(errorDescription)"
                )
            case let .cancelled(attempts, _):
                titles.append("cancelled:\(attempts)")
            }
        }

        return titles
    }

    func progressTitle(_ progress: MHMutationProgress) -> String {
        switch progress {
        case let .retryScheduled(nextAttempt, delay):
            return "progress:retryScheduled:\(nextAttempt):\(delay)"
        case let .stepStarted(name, completedSteps, totalSteps):
            return "progress:stepStarted:\(name):\(completedSteps)/\(totalSteps)"
        case let .stepSucceeded(name, completedSteps, totalSteps):
            return "progress:stepSucceeded:\(name):\(completedSteps)/\(totalSteps)"
        }
    }
}
