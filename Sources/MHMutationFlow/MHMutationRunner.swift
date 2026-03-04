import Foundation

/// Runs a mutation with retry, cancellation, and post-success side effects.
public enum MHMutationRunner {
    private enum StepResult {
        case succeeded([String])
        case failed(any Error, [String])
        case cancelled([String])
    }

    private enum AttemptResult<Value> {
        case completed(MHMutationOutcome<Value>)
        case retry
    }

    private enum RunnerError: Error {
        case unreachableState
    }

    private struct RunSettings {
        let retryPolicy: MHMutationRetryPolicy
        let cancellationHandle: MHCancellationHandle?
        let afterSuccess: [MHMutationStep]
    }

    /// Executes a mutation flow and returns a deterministic outcome.
    @preconcurrency
    public static func run<Value>(
        operation: @Sendable () async throws -> Value,
        retryPolicy: MHMutationRetryPolicy = .none,
        cancellationHandle: MHCancellationHandle? = nil,
        afterSuccess: [MHMutationStep] = [],
        onEvent: @Sendable (MHMutationEvent) -> Void = { _ in () }
    ) async -> MHMutationOutcome<Value> {
        let settings = RunSettings(
            retryPolicy: retryPolicy,
            cancellationHandle: cancellationHandle,
            afterSuccess: afterSuccess
        )

        if isCancelled(cancellationHandle) {
            return cancelledOutcome(
                attempts: .zero,
                completedSteps: [],
                onEvent: onEvent
            )
        }

        var attempt = 1
        while attempt <= retryPolicy.maximumAttempts {
            if isCancelled(cancellationHandle) {
                return cancelledOutcome(
                    attempts: attempt - 1,
                    completedSteps: [],
                    onEvent: onEvent
                )
            }

            let attemptResult = await runAttempt(
                attempt: attempt,
                operation: operation,
                settings: settings,
                onEvent: onEvent
            )
            switch attemptResult {
            case .completed(let outcome):
                return outcome
            case .retry:
                attempt += 1
            }
        }

        return .failed(
            error: RunnerError.unreachableState,
            attempts: retryPolicy.maximumAttempts,
            completedSteps: []
        )
    }

    private static func runAttempt<Value>(
        attempt: Int,
        operation: @Sendable () async throws -> Value,
        settings: RunSettings,
        onEvent: @Sendable (MHMutationEvent) -> Void
    ) async -> AttemptResult<Value> {
        onEvent(.attemptStarted(attempt))

        do {
            let value = try await operation()
            onEvent(.attemptSucceeded(attempt))
            return await handleSuccessfulAttempt(
                value: value,
                attempt: attempt,
                cancellationHandle: settings.cancellationHandle,
                afterSuccess: settings.afterSuccess,
                onEvent: onEvent
            )
        } catch is CancellationError {
            return .completed(
                cancelledOutcome(
                    attempts: attempt,
                    completedSteps: [],
                    onEvent: onEvent
                )
            )
        } catch {
            return await handleFailedAttempt(
                error: error,
                attempt: attempt,
                retryPolicy: settings.retryPolicy,
                onEvent: onEvent
            )
        }
    }

    private static func handleSuccessfulAttempt<Value>(
        value: Value,
        attempt: Int,
        cancellationHandle: MHCancellationHandle?,
        afterSuccess: [MHMutationStep],
        onEvent: @Sendable (MHMutationEvent) -> Void
    ) async -> AttemptResult<Value> {
        let stepResult = await executeAfterSuccessSteps(
            afterSuccess,
            cancellationHandle: cancellationHandle,
            onEvent: onEvent
        )

        switch stepResult {
        case .succeeded(let completedSteps):
            if isCancelled(cancellationHandle) {
                return .completed(
                    cancelledOutcome(
                        attempts: attempt,
                        completedSteps: completedSteps,
                        onEvent: onEvent
                    )
                )
            }
            return .completed(
                .succeeded(
                    value: value,
                    attempts: attempt,
                    completedSteps: completedSteps
                )
            )
        case let .failed(error, completedSteps):
            return .completed(
                .failed(
                    error: error,
                    attempts: attempt,
                    completedSteps: completedSteps
                )
            )
        case .cancelled(let completedSteps):
            return .completed(
                cancelledOutcome(
                    attempts: attempt,
                    completedSteps: completedSteps,
                    onEvent: onEvent
                )
            )
        }
    }

    private static func handleFailedAttempt<Value>(
        error: any Error,
        attempt: Int,
        retryPolicy: MHMutationRetryPolicy,
        onEvent: @Sendable (MHMutationEvent) -> Void
    ) async -> AttemptResult<Value> {
        onEvent(.attemptFailed(attempt, String(describing: error)))
        guard attempt < retryPolicy.maximumAttempts else {
            return .completed(
                .failed(
                    error: error,
                    attempts: attempt,
                    completedSteps: []
                )
            )
        }

        let canRetry = await waitForRetry(
            backoff: retryPolicy.backoff
        )
        guard canRetry else {
            return .completed(
                cancelledOutcome(
                    attempts: attempt,
                    completedSteps: [],
                    onEvent: onEvent
                )
            )
        }
        return .retry
    }

    private static func executeAfterSuccessSteps(
        _ steps: [MHMutationStep],
        cancellationHandle: MHCancellationHandle?,
        onEvent: @Sendable (MHMutationEvent) -> Void
    ) async -> StepResult {
        var completedSteps = [String]()

        for step in steps {
            if isCancelled(cancellationHandle) {
                return .cancelled(completedSteps)
            }

            onEvent(.stepStarted(step.name))
            do {
                try await step.action()
                completedSteps.append(step.name)
                onEvent(.stepSucceeded(step.name))
            } catch is CancellationError {
                return .cancelled(completedSteps)
            } catch {
                onEvent(.stepFailed(step.name, String(describing: error)))
                return .failed(error, completedSteps)
            }
        }

        return .succeeded(completedSteps)
    }

    private static func waitForRetry(backoff: MHMutationBackoff) async -> Bool {
        switch backoff {
        case .immediate:
            return true
        case .fixed(let duration):
            do {
                try await Task.sleep(for: duration)
                return true
            } catch {
                return false
            }
        }
    }

    private static func cancelledOutcome<Value>(
        attempts: Int,
        completedSteps: [String],
        onEvent: @Sendable (MHMutationEvent) -> Void
    ) -> MHMutationOutcome<Value> {
        onEvent(.cancelled)
        return .cancelled(
            attempts: attempts,
            completedSteps: completedSteps
        )
    }

    private static func isCancelled(_ cancellationHandle: MHCancellationHandle?) -> Bool {
        Task.isCancelled || cancellationHandle?.isCancelled == true
    }
}
