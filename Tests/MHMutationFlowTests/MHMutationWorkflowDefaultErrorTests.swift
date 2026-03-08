import MHMutationFlow
import Testing

struct MHMutationWorkflowDefaultErrorTests {
    actor Recorder {
        private var values = [String]()

        func record(_ value: String) {
            values.append(value)
        }

        func allValues() -> [String] {
            values
        }
    }

    private struct WrappedValue: Sendable {
        let value: String
        let followUp: FollowUp
    }

    private struct FollowUp: Sendable {
        let reloadWidgets: Bool
        let synchronizeNotifications: Bool
    }

    private enum OperationTestError: Error {
        case failed
    }

    @Test
    func runThrowing_returns_value_and_runs_adapter_steps_in_order() async throws {
        let recorder = Recorder()
        let adapter = MHMutationAdapter<String>.fixed(
            [
                .init(name: "reloadWidgets") {
                    await recorder.record("reloadWidgets")
                },
                .init(name: "synchronizeNotifications") {
                    await recorder.record("synchronizeNotifications")
                }
            ]
        )

        let result = try await MHMutationWorkflow.runThrowing(
            name: "saveDraft",
            operation: {
                "saved"
            },
            adapter: adapter
        )

        #expect(result == "saved")
        #expect(await recorder.allValues() == [
            "reloadWidgets",
            "synchronizeNotifications"
        ])
    }

    @Test
    func runThrowing_projects_after_success_input_and_return_value() async throws {
        let recorder = Recorder()
        let adapter = MHMutationAdapter<FollowUp> { followUp in
            var steps = [MHMutationStep]()

            if followUp.reloadWidgets {
                steps.append(
                    .init(name: "reloadWidgets") {
                        await recorder.record("reloadWidgets")
                    }
                )
            }

            if followUp.synchronizeNotifications {
                steps.append(
                    .init(name: "synchronizeNotifications") {
                        await recorder.record("synchronizeNotifications")
                    }
                )
            }

            return steps
        }

        let result = try await MHMutationWorkflow.runThrowing(
            name: "saveWrappedDraft",
            operation: { () -> WrappedValue in
                .init(
                    value: "saved",
                    followUp: .init(
                        reloadWidgets: true,
                        synchronizeNotifications: true
                    )
                )
            },
            adapter: adapter,
            afterSuccess: { (wrappedValue: WrappedValue) in
                wrappedValue.followUp
            },
            returning: { (wrappedValue: WrappedValue) in
                wrappedValue.value
            }
        )

        #expect(result == "saved")
        #expect(await recorder.allValues() == [
            "reloadWidgets",
            "synchronizeNotifications"
        ])
    }

    @Test
    func runThrowing_maps_operation_failure_with_custom_description() async {
        let operationErrorDescription: @Sendable (any Error) -> String = { _ in
            "displayable failure"
        }

        await #expect(throws: MHMutationWorkflowError.operation("displayable failure")) {
            try await MHMutationWorkflow.runThrowing(
                name: "saveDraft",
                operation: {
                    throw OperationTestError.failed
                },
                adapter: MHMutationAdapter<String>.none,
                configuration: .init(
                    operationErrorDescription: operationErrorDescription
                )
            )
        }
    }

    @Test
    func runThrowing_maps_step_failure() async {
        let adapter = MHMutationAdapter<String>.fixed(
            [
                .init(name: "synchronizeNotifications") {
                    throw OperationTestError.failed
                }
            ]
        )

        await #expect(
            throws: MHMutationWorkflowError.step(
                name: "synchronizeNotifications",
                description: "failed"
            )
        ) {
            try await MHMutationWorkflow.runThrowing(
                name: "saveDraft",
                operation: {
                    "saved"
                },
                adapter: adapter
            )
        }
    }

    @Test
    func runThrowing_preserves_cancellation() async {
        await #expect(throws: CancellationError.self) {
            try await MHMutationWorkflow.runThrowing(
                name: "saveDraft",
                operation: {
                    throw CancellationError()
                },
                adapter: MHMutationAdapter<String>.none
            )
        }
    }
}
