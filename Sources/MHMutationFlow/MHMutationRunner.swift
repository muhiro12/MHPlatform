import Foundation

/// Runs a mutation with retry, cancellation, and post-success side effects.
public enum MHMutationRunner {
    /// Sleep abstraction for deterministic retry testing.
    public typealias Sleep = @Sendable (Duration) async throws -> Void

    private enum StepExecutionResult {
        case succeeded(completedSteps: [String])
        case failed(
                stepName: String,
                errorDescription: String,
                completedSteps: [String]
             )
        case cancelled(completedSteps: [String])
    }

    /// Starts a mutation run and returns a handle with event stream and terminal outcome.
    @preconcurrency
    public static func start<Value: Sendable>(
        mutation: MHMutation<Value>,
        retryPolicy: MHMutationRetryPolicy = .none,
        cancellationHandle: MHCancellationHandle? = nil,
        afterSuccess: [MHMutationStep] = [],
        sleep: @escaping Sleep = { duration in
            if duration > .zero {
                try await Task.sleep(for: duration)
            }
        }
    ) -> MHMutationRun<Value> {
        let stream = AsyncStream<MHMutationEvent<Value>>.makeStream()

        let outcomeTask = Task<MHMutationOutcome<Value>, Never> {
            defer {
                stream.continuation.finish()
            }

            return await run(
                mutation: mutation,
                retryPolicy: retryPolicy,
                cancellationHandle: cancellationHandle,
                afterSuccess: afterSuccess,
                sleep: sleep
            )                { event in
                    stream.continuation.yield(event)
                }
        }

        return .init(
            events: stream.stream,
            outcome: outcomeTask
        )
    }

    /// Runs a mutation and waits for its terminal outcome.
    @preconcurrency
    public static func run<Value: Sendable>(
        mutation: MHMutation<Value>,
        retryPolicy: MHMutationRetryPolicy = .none,
        cancellationHandle: MHCancellationHandle? = nil,
        afterSuccess: [MHMutationStep] = [],
        sleep: @escaping Sleep = { duration in
            if duration > .zero {
                try await Task.sleep(for: duration)
            }
        }
    ) async -> MHMutationOutcome<Value> {
        let runHandle = start(
            mutation: mutation,
            retryPolicy: retryPolicy,
            cancellationHandle: cancellationHandle,
            afterSuccess: afterSuccess,
            sleep: sleep
        )

        return await runHandle.outcome.value
    }
}

private extension MHMutationRunner {
    static func run<Value: Sendable>(
        mutation: MHMutation<Value>,
        retryPolicy: MHMutationRetryPolicy,
        cancellationHandle: MHCancellationHandle?,
        afterSuccess: [MHMutationStep],
        sleep: @escaping Sleep,
        emit: @escaping @Sendable (MHMutationEvent<Value>) -> Void
    ) async -> MHMutationOutcome<Value> {
        if isCancelled(cancellationHandle) {
            let outcome = MHMutationOutcome<Value>.cancelled(
                attempts: .zero,
                completedSteps: []
            )
            emitCancelled(outcome: outcome, emit: emit)
            return outcome
        }

        var attempt = 1

        while attempt <= retryPolicy.maximumAttempts {
            if isCancelled(cancellationHandle) {
                let outcome = MHMutationOutcome<Value>.cancelled(
                    attempts: attempt - 1,
                    completedSteps: []
                )
                emitCancelled(outcome: outcome, emit: emit)
                return outcome
            }

            emit(
                .started(
                    mutation: mutation.name,
                    attempt: attempt
                )
            )

            do {
                let value = try await mutation.operation()
                let stepResult = await runSteps(
                    steps: afterSuccess,
                    cancellationHandle: cancellationHandle,
                    emit: emit
                )

                switch stepResult {
                case .succeeded(let completedSteps):
                    if isCancelled(cancellationHandle) {
                        let outcome = MHMutationOutcome<Value>.cancelled(
                            attempts: attempt,
                            completedSteps: completedSteps
                        )
                        emitCancelled(outcome: outcome, emit: emit)
                        return outcome
                    }

                    let outcome = MHMutationOutcome<Value>.succeeded(
                        value: value,
                        attempts: attempt,
                        completedSteps: completedSteps
                    )
                    emit(
                        .succeeded(
                            value: value,
                            attempts: attempt,
                            completedSteps: completedSteps
                        )
                    )
                    return outcome

                case let .failed(stepName, errorDescription, completedSteps):
                    let outcome = MHMutationOutcome<Value>.failed(
                        failure: .step(
                            name: stepName,
                            errorDescription: errorDescription
                        ),
                        attempts: attempt,
                        completedSteps: completedSteps,
                        isRecoverable: false
                    )
                    emit(
                        .failed(
                            errorDescription: errorDescription,
                            attempts: attempt,
                            completedSteps: completedSteps,
                            isRecoverable: false
                        )
                    )
                    return outcome

                case .cancelled(let completedSteps):
                    let outcome = MHMutationOutcome<Value>.cancelled(
                        attempts: attempt,
                        completedSteps: completedSteps
                    )
                    emitCancelled(outcome: outcome, emit: emit)
                    return outcome
                }
            } catch is CancellationError {
                let outcome = MHMutationOutcome<Value>.cancelled(
                    attempts: attempt,
                    completedSteps: []
                )
                emitCancelled(outcome: outcome, emit: emit)
                return outcome
            } catch {
                let errorDescription = String(describing: error)
                let canRetry = attempt < retryPolicy.maximumAttempts
                emit(
                    .failed(
                        errorDescription: errorDescription,
                        attempts: attempt,
                        completedSteps: [],
                        isRecoverable: canRetry
                    )
                )

                guard canRetry else {
                    return .failed(
                        failure: .operation(errorDescription: errorDescription),
                        attempts: attempt,
                        completedSteps: [],
                        isRecoverable: false
                    )
                }

                let delay = retryPolicy.backoff.delay(forRetry: attempt)
                emit(
                    .progress(
                        .retryScheduled(
                            nextAttempt: attempt + 1,
                            delay: delay
                        )
                    )
                )

                let canContinue = await waitForRetry(
                    delay: delay,
                    cancellationHandle: cancellationHandle,
                    sleep: sleep
                )

                guard canContinue else {
                    let outcome = MHMutationOutcome<Value>.cancelled(
                        attempts: attempt,
                        completedSteps: []
                    )
                    emitCancelled(outcome: outcome, emit: emit)
                    return outcome
                }

                attempt += 1
            }
        }

        return .failed(
            failure: .operation(errorDescription: "Unreachable mutation state."),
            attempts: retryPolicy.maximumAttempts,
            completedSteps: [],
            isRecoverable: false
        )
    }

    private static func runSteps<Value: Sendable>(
        steps: [MHMutationStep],
        cancellationHandle: MHCancellationHandle?,
        emit: @Sendable (MHMutationEvent<Value>) -> Void
    ) async -> StepExecutionResult {
        var completedSteps = [String]()

        for step in steps {
            if isCancelled(cancellationHandle) {
                return .cancelled(completedSteps: completedSteps)
            }

            emit(
                .progress(
                    .stepStarted(
                        name: step.name,
                        completedSteps: completedSteps.count,
                        totalSteps: steps.count
                    )
                )
            )

            do {
                try await step.action()
                completedSteps.append(step.name)
                emit(
                    .progress(
                        .stepSucceeded(
                            name: step.name,
                            completedSteps: completedSteps.count,
                            totalSteps: steps.count
                        )
                    )
                )
            } catch is CancellationError {
                return .cancelled(completedSteps: completedSteps)
            } catch {
                return .failed(
                    stepName: step.name,
                    errorDescription: String(describing: error),
                    completedSteps: completedSteps
                )
            }
        }

        return .succeeded(completedSteps: completedSteps)
    }

    static func waitForRetry(
        delay: Duration,
        cancellationHandle: MHCancellationHandle?,
        sleep: Sleep
    ) async -> Bool {
        if delay == .zero {
            return isCancelled(cancellationHandle) == false
        }

        do {
            try await sleep(delay)
        } catch {
            return false
        }

        return isCancelled(cancellationHandle) == false
    }

    static func emitCancelled<Value: Sendable>(
        outcome: MHMutationOutcome<Value>,
        emit: @Sendable (MHMutationEvent<Value>) -> Void
    ) {
        guard case let .cancelled(attempts, completedSteps) = outcome else {
            return
        }

        emit(
            .cancelled(
                attempts: attempts,
                completedSteps: completedSteps
            )
        )
    }

    static func isCancelled(_ cancellationHandle: MHCancellationHandle?) -> Bool {
        Task.isCancelled || cancellationHandle?.isCancelled == true
    }
}
