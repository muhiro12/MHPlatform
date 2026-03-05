import Foundation

/// Runs a mutation with retry, cancellation, and post-success side effects.
public enum MHMutationRunner {
    /// Sleep abstraction for deterministic retry testing.
    public typealias Sleep = @Sendable (Duration) async throws -> Void

    enum StepExecutionResult {
        case succeeded(completedSteps: [String])
        case failed(
                stepName: String,
                errorDescription: String,
                completedSteps: [String]
             )
        case cancelled(completedSteps: [String])
    }

    enum AttemptDecision<Value: Sendable> {
        case finish(MHMutationOutcome<Value>)
        case retry(nextAttempt: Int)
    }

    struct RunContext<Value: Sendable> {
        let mutation: MHMutation<Value>
        let retryPolicy: MHMutationRetryPolicy
        let cancellationHandle: MHCancellationHandle?
        let afterSuccess: [MHMutationStep]
        let sleep: Sleep
        let emit: @Sendable (MHMutationEvent<Value>) -> Void
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
        let emit: @Sendable (MHMutationEvent<Value>) -> Void = { event in
            stream.continuation.yield(event)
        }

        let context = RunContext(
            mutation: mutation,
            retryPolicy: retryPolicy,
            cancellationHandle: cancellationHandle,
            afterSuccess: afterSuccess,
            sleep: sleep,
            emit: emit
        )

        let outcomeTask = Task<MHMutationOutcome<Value>, Never> {
            defer {
                stream.continuation.finish()
            }
            return await run(context: context)
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

extension MHMutationRunner {
    static func run<Value: Sendable>(
        context: RunContext<Value>
    ) async -> MHMutationOutcome<Value> {
        if isCancelled(context.cancellationHandle) {
            return cancelledOutcome(
                attempts: 0,
                completedSteps: [],
                emit: context.emit
            )
        }

        var attempt = 1

        while attempt <= context.retryPolicy.maximumAttempts {
            if isCancelled(context.cancellationHandle) {
                return cancelledOutcome(
                    attempts: attempt - 1,
                    completedSteps: [],
                    emit: context.emit
                )
            }

            context.emit(
                .started(
                    mutation: context.mutation.name,
                    attempt: attempt
                )
            )

            let decision = await runAttempt(
                attempt: attempt,
                context: context
            )

            switch decision {
            case let .finish(outcome):
                return outcome
            case let .retry(nextAttempt):
                attempt = nextAttempt
            }
        }

        return .failed(
            failure: .operation(errorDescription: "Unreachable mutation state."),
            attempts: context.retryPolicy.maximumAttempts,
            completedSteps: [],
            isRecoverable: false
        )
    }
}
