import MHMutationFlow
import Testing

struct MHMutationWorkflowKeyPathProjectionTests {
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
    func runThrowing_projects_adapter_input_from_key_path_and_returns_full_value() async throws {
        let recorder = Recorder()
        let adapter = Self.followUpAdapter(recorder: recorder)

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
            adapterValue: \.followUp
        )

        #expect(result.value == "saved")
        #expect(result.followUp.reloadWidgets)
        #expect(result.followUp.synchronizeNotifications)
        #expect(await recorder.allValues() == [
            "reloadWidgets",
            "synchronizeNotifications"
        ])
    }

    @Test
    func runThrowing_projects_key_path_adapter_input_and_result_value() async throws {
        let recorder = Recorder()
        let adapter = Self.followUpAdapter(recorder: recorder)

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
            adapterValue: \.followUp,
            resultValue: \.value
        )

        #expect(result == "saved")
        #expect(await recorder.allValues() == [
            "reloadWidgets",
            "synchronizeNotifications"
        ])
    }

    @Test
    func runThrowing_key_path_projection_maps_operation_failure_with_custom_description() async {
        let operationErrorDescription: @Sendable (any Error) -> String = { _ in
            "displayable failure"
        }

        await #expect(
            throws: MHMutationWorkflowError.operation("displayable failure")
        ) {
            try await MHMutationWorkflow.runThrowing(
                name: "saveWrappedDraft",
                operation: { () -> WrappedValue in
                    throw OperationTestError.failed
                },
                adapter: MHMutationAdapter<FollowUp>.none,
                adapterValue: \.followUp,
                resultValue: \.value,
                configuration: .init(
                    operationErrorDescription: operationErrorDescription
                )
            )
        }
    }

    @Test
    func runThrowing_key_path_projection_maps_step_failure() async {
        let adapter = MHMutationAdapter<FollowUp>.fixed(
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
                adapterValue: \.followUp,
                resultValue: \.value
            )
        }
    }

    @Test
    func runThrowing_key_path_projection_preserves_cancellation() async {
        await #expect(throws: CancellationError.self) {
            try await MHMutationWorkflow.runThrowing(
                name: "saveWrappedDraft",
                operation: { () -> WrappedValue in
                    throw CancellationError()
                },
                adapter: MHMutationAdapter<FollowUp>.none,
                adapterValue: \.followUp,
                resultValue: \.value
            )
        }
    }
}

private extension MHMutationWorkflowKeyPathProjectionTests {
    private static func followUpAdapter(recorder: Recorder) -> MHMutationAdapter<FollowUp> {
        .init { followUp in
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
    }
}
