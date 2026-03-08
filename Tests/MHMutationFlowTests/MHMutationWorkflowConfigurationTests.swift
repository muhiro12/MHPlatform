import MHMutationFlow
import Testing

struct MHMutationWorkflowConfigurationTests {
    @MainActor
    final class AttemptCounter {
        private(set) var attempts = 0

        func nextAttempt() -> Int {
            attempts += 1
            return attempts
        }
    }

    private enum OperationTestError: Error {
        case failed
    }

    @Test
    @MainActor
    func runThrowing_configuration_retries_until_operation_succeeds() async throws {
        let attemptCounter = AttemptCounter()

        let result = try await MHMutationWorkflow.runThrowing(
            name: "saveDraft",
            operation: {
                let attempt = attemptCounter.nextAttempt()
                guard attempt > 1 else {
                    throw OperationTestError.failed
                }

                return "saved"
            },
            adapter: MHMutationAdapter<String>.none,
            configuration: .init(
                retryPolicy: .init(
                    maximumAttempts: 2,
                    backoff: .immediate
                )
            )
        )

        #expect(result == "saved")
        #expect(attemptCounter.attempts == 2)
    }

    @Test
    func runThrowing_configuration_respects_pre_cancelled_handle() async {
        let cancellationHandle = MHCancellationHandle()
        cancellationHandle.cancel()

        await #expect(throws: CancellationError.self) {
            try await MHMutationWorkflow.runThrowing(
                name: "saveDraft",
                operation: {
                    "saved"
                },
                adapter: MHMutationAdapter<String>.none,
                configuration: .init(
                    cancellationHandle: cancellationHandle
                )
            )
        }
    }
}
