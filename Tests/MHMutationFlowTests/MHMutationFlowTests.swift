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

    private final class EventRecorder: @unchecked Sendable {
        private let lock = NSLock()
        private var values = [String]()

        private static func description(for event: MHMutationEvent) -> String {
            switch event {
            case .attemptStarted(let attempt):
                return "attemptStarted:\(attempt)"
            case .attemptFailed(let attempt, _):
                return "attemptFailed:\(attempt)"
            case .attemptSucceeded(let attempt):
                return "attemptSucceeded:\(attempt)"
            case .stepStarted(let name):
                return "stepStarted:\(name)"
            case .stepSucceeded(let name):
                return "stepSucceeded:\(name)"
            case .stepFailed(let name, _):
                return "stepFailed:\(name)"
            case .cancelled:
                return "cancelled"
            }
        }

        func record(_ event: MHMutationEvent) {
            lock.lock()
            values.append(Self.description(for: event))
            lock.unlock()
        }

        func events() -> [String] {
            lock.lock()
            let snapshot = values
            lock.unlock()
            return snapshot
        }
    }

    private enum MutationTestError: Error {
        case operationFailed
        case sideEffectFailed
    }

    @Test
    func succeeds_without_retry() async {
        let outcome = await MHMutationRunner.run(
            operation: {
                "saved"
            },
            afterSuccess: [
                .init(name: "reloadWidgets") {
                    // no-op
                }
            ]
        )

        switch outcome {
        case let .succeeded(value, attempts, completedSteps):
            #expect(value == "saved")
            #expect(attempts == 1)
            #expect(completedSteps == ["reloadWidgets"])
        case .failed, .cancelled:
            Issue.record("Expected success outcome")
        }
    }

    @Test
    func retries_and_succeeds_on_second_attempt() async {
        let state = AttemptState()
        let outcome = await MHMutationRunner.run(
            operation: {
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
        )

        switch outcome {
        case let .succeeded(value, attempts, completedSteps):
            #expect(value == "saved")
            #expect(attempts == 2)
            #expect(completedSteps.isEmpty)
        case .failed, .cancelled:
            Issue.record("Expected success outcome")
        }
    }

    @Test
    func fails_after_retry_exhaustion() async {
        let outcome = await MHMutationRunner.run(
            operation: {
                throw MutationTestError.operationFailed
            },
            retryPolicy: .init(
                maximumAttempts: 3,
                backoff: .immediate
            )
        )

        switch outcome {
        case let .failed(_, attempts, completedSteps):
            #expect(attempts == 3)
            #expect(completedSteps.isEmpty)
        case .succeeded, .cancelled:
            Issue.record("Expected failure outcome")
        }
    }

    @Test
    func does_not_rerun_operation_when_side_effect_fails() async {
        let state = AttemptState()
        let outcome = await MHMutationRunner.run(
            operation: {
                _ = await state.nextAttempt()
                return "saved"
            },
            retryPolicy: .init(
                maximumAttempts: 3,
                backoff: .immediate
            ),
            afterSuccess: [
                .init(name: "reloadWidgets") {
                    // no-op
                },
                .init(name: "syncNotifications") {
                    throw MutationTestError.sideEffectFailed
                }
            ]
        )

        let totalAttempts = await state.attempts()

        switch outcome {
        case let .failed(_, attempts, completedSteps):
            #expect(attempts == 1)
            #expect(totalAttempts == 1)
            #expect(completedSteps == ["reloadWidgets"])
        case .succeeded, .cancelled:
            Issue.record("Expected failure outcome")
        }
    }

    @Test
    func returns_cancelled_before_start() async {
        let cancellationHandle = MHCancellationHandle()
        cancellationHandle.cancel()

        let outcome = await MHMutationRunner.run(
            operation: {
                "saved"
            },
            cancellationHandle: cancellationHandle
        )

        switch outcome {
        case let .cancelled(attempts, completedSteps):
            #expect(attempts == 0)
            #expect(completedSteps.isEmpty)
        case .succeeded, .failed:
            Issue.record("Expected cancelled outcome")
        }
    }

    @Test
    func returns_cancelled_between_side_effects() async {
        let cancellationHandle = MHCancellationHandle()

        let outcome = await MHMutationRunner.run(
            operation: {
                "saved"
            },
            cancellationHandle: cancellationHandle,
            afterSuccess: [
                .init(name: "reloadWidgets") {
                    cancellationHandle.cancel()
                },
                .init(name: "syncNotifications") {
                    // no-op
                }
            ]
        )

        switch outcome {
        case let .cancelled(attempts, completedSteps):
            #expect(attempts == 1)
            #expect(completedSteps == ["reloadWidgets"])
        case .succeeded, .failed:
            Issue.record("Expected cancelled outcome")
        }
    }

    @Test
    func emits_ordered_events() async {
        let recorder = EventRecorder()
        let eventSink: @Sendable (MHMutationEvent) -> Void = { event in
            recorder.record(event)
        }

        _ = await MHMutationRunner.run(
            operation: {
                "saved"
            },
            afterSuccess: [
                .init(name: "reloadWidgets") {
                    // no-op
                },
                .init(name: "syncNotifications") {
                    // no-op
                }
            ],
            onEvent: eventSink
        )

        let events = recorder.events()

        #expect(events == [
            "attemptStarted:1",
            "attemptSucceeded:1",
            "stepStarted:reloadWidgets",
            "stepSucceeded:reloadWidgets",
            "stepStarted:syncNotifications",
            "stepSucceeded:syncNotifications"
        ])
    }
}
