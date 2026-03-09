import Foundation

/// Runs destructive reset steps in declaration order.
public enum MHDestructiveResetService {
    private struct NonSendableErrorWrapper: CustomStringConvertible, Error, LocalizedError, Sendable {
        let message: String

        var description: String {
            message
        }

        var errorDescription: String? {
            message
        }
    }

    /// Executes reset steps sequentially and returns a deterministic outcome.
    @preconcurrency
    public static func run(
        steps: [MHDestructiveResetStep],
        onEvent: @Sendable (MHDestructiveResetEvent) -> Void = { _ in () }
    ) async -> MHDestructiveResetOutcome {
        var completedSteps = [String]()

        for step in steps {
            onEvent(.stepStarted(name: step.name))

            do {
                try await step.action()
                completedSteps.append(step.name)
                onEvent(.stepSucceeded(name: step.name))
            } catch {
                onEvent(
                    .stepFailed(
                        name: step.name,
                        message: String(describing: error)
                    )
                )
                return .failed(
                    error: sendableError(from: error),
                    failedStep: step.name,
                    completedSteps: completedSteps
                )
            }
        }

        onEvent(.completed)
        return .succeeded(completedSteps: completedSteps)
    }

    /// Executes reset steps sequentially and throws when the first step fails.
    @preconcurrency
    public static func runThrowing(
        steps: [MHDestructiveResetStep],
        onEvent: @Sendable (MHDestructiveResetEvent) -> Void = { _ in () }
    ) async throws -> [String] {
        let outcome = await run(
            steps: steps,
            onEvent: onEvent
        )

        switch outcome {
        case .succeeded(let completedSteps):
            return completedSteps
        case .failed(let error, _, _):
            throw error
        }
    }
}

private extension MHDestructiveResetService {
    static func sendableError(
        from error: any Error
    ) -> any Error & Sendable {
        NonSendableErrorWrapper(
            message: String(describing: error)
        )
    }
}
