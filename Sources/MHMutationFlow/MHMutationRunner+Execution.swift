import Foundation

extension MHMutationRunner {
    static func runAttempt<Value: Sendable>(
        attempt: Int,
        context: RunContext<Value>
    ) async -> AttemptDecision<Value> {
        do {
            let value = try await context.mutation.operation()
            return await handleOperationSuccess(
                value: value,
                attempt: attempt,
                context: context
            )
        } catch is CancellationError {
            return .finish(
                cancelledOutcome(
                    attempts: attempt,
                    completedSteps: [],
                    emit: context.emit
                )
            )
        } catch {
            return await handleOperationFailure(
                error: error,
                attempt: attempt,
                context: context
            )
        }
    }

    static func handleOperationSuccess<Value: Sendable>(
        value: Value,
        attempt: Int,
        context: RunContext<Value>
    ) async -> AttemptDecision<Value> {
        if isCancelled(context.cancellationHandle) {
            return .finish(
                cancelledOutcome(
                    attempts: attempt,
                    completedSteps: [],
                    emit: context.emit
                )
            )
        }

        let steps = context.adapter.steps(for: value)
        let stepResult = await runSteps(
            steps: steps,
            cancellationHandle: context.cancellationHandle,
            emit: context.emit
        )

        switch stepResult {
        case .succeeded(let completedSteps):
            return handleSucceededStepResult(
                value: value,
                attempt: attempt,
                completedSteps: completedSteps,
                context: context
            )

        case let .failed(stepName, errorDescription, completedSteps):
            return handleFailedStepResult(
                stepName: stepName,
                errorDescription: errorDescription,
                attempt: attempt,
                completedSteps: completedSteps,
                context: context
            )

        case .cancelled(let completedSteps):
            return .finish(
                cancelledOutcome(
                    attempts: attempt,
                    completedSteps: completedSteps,
                    emit: context.emit
                )
            )
        }
    }

    static func handleSucceededStepResult<Value: Sendable>(
        value: Value,
        attempt: Int,
        completedSteps: [String],
        context: RunContext<Value>
    ) -> AttemptDecision<Value> {
        if isCancelled(context.cancellationHandle) {
            return .finish(
                cancelledOutcome(
                    attempts: attempt,
                    completedSteps: completedSteps,
                    emit: context.emit
                )
            )
        }

        let outcome = MHMutationOutcome<Value>.succeeded(
            value: value,
            attempts: attempt,
            completedSteps: completedSteps
        )
        context.emit(
            .succeeded(
                value: value,
                attempts: attempt,
                completedSteps: completedSteps
            )
        )
        return .finish(outcome)
    }

    static func handleFailedStepResult<Value: Sendable>(
        stepName: String,
        errorDescription: String,
        attempt: Int,
        completedSteps: [String],
        context: RunContext<Value>
    ) -> AttemptDecision<Value> {
        let outcome = MHMutationOutcome<Value>.failed(
            failure: .step(
                name: stepName,
                errorDescription: errorDescription
            ),
            attempts: attempt,
            completedSteps: completedSteps,
            isRecoverable: false
        )
        context.emit(
            .failed(
                errorDescription: errorDescription,
                attempts: attempt,
                completedSteps: completedSteps,
                isRecoverable: false
            )
        )
        return .finish(outcome)
    }

    static func handleOperationFailure<Value: Sendable>(
        error: any Error,
        attempt: Int,
        context: RunContext<Value>
    ) async -> AttemptDecision<Value> {
        let errorDescription = String(describing: error)
        let canRetry = attempt < context.retryPolicy.maximumAttempts

        context.emit(
            .failed(
                errorDescription: errorDescription,
                attempts: attempt,
                completedSteps: [],
                isRecoverable: canRetry
            )
        )

        guard canRetry else {
            return .finish(
                .failed(
                    failure: .operation(errorDescription: errorDescription),
                    attempts: attempt,
                    completedSteps: [],
                    isRecoverable: false
                )
            )
        }

        let delay = context.retryPolicy.backoff.delay(forRetry: attempt)
        context.emit(
            .progress(
                .retryScheduled(
                    nextAttempt: attempt + 1,
                    delay: delay
                )
            )
        )

        let canContinue = await waitForRetry(
            delay: delay,
            cancellationHandle: context.cancellationHandle,
            sleep: context.sleep
        )

        guard canContinue else {
            return .finish(
                cancelledOutcome(
                    attempts: attempt,
                    completedSteps: [],
                    emit: context.emit
                )
            )
        }

        return .retry(nextAttempt: attempt + 1)
    }

    static func runSteps<Value: Sendable>(
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

    static func cancelledOutcome<Value: Sendable>(
        attempts: Int,
        completedSteps: [String],
        emit: @Sendable (MHMutationEvent<Value>) -> Void
    ) -> MHMutationOutcome<Value> {
        let outcome = MHMutationOutcome<Value>.cancelled(
            attempts: attempts,
            completedSteps: completedSteps
        )
        emitCancelled(outcome: outcome, emit: emit)
        return outcome
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
