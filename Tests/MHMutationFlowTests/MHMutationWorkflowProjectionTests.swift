import MHMutationFlow
import Testing

struct MHMutationWorkflowProjectionTests {
    actor Recorder {
        private var values = [String]()

        func record(_ value: String) {
            values.append(value)
        }

        func allValues() -> [String] {
            values
        }
    }

    private struct FollowUp: Sendable {
        let reloadWidgets: Bool
        let synchronizeNotifications: Bool
    }

    private enum ExpectedError: Error, Equatable, Sendable {
        case operation(String)
        case step(name: String, description: String)
    }

    private enum OperationTestError: Error {
        case failed
    }

    @Test
    func runThrowing_projection_carrier_supports_key_path_projection() async throws {
        let recorder = Recorder()
        let adapter = Self.followUpAdapter(recorder: recorder)

        let result = try await MHMutationWorkflow.runThrowing(
            name: "saveProjectedDraft",
            operation: { () -> MHMutationProjection<FollowUp, String> in
                .init(
                    adapterValue: .init(
                        reloadWidgets: true,
                        synchronizeNotifications: true
                    ),
                    resultValue: "saved"
                )
            },
            adapter: adapter,
            projection: .keyPaths(
                adapterValue: \MHMutationProjection<FollowUp, String>.adapterValue,
                resultValue: \MHMutationProjection<FollowUp, String>.resultValue
            ),
            mapFailure: Self.expectedError(from:)
        )

        #expect(result == "saved")
        #expect(await recorder.allValues() == [
            "reloadWidgets",
            "synchronizeNotifications"
        ])
    }

    @Test
    func runThrowing_fixed_adapter_value_supports_void_mutations() async throws {
        let recorder = Recorder()
        let adapter = Self.followUpAdapter(recorder: recorder)

        try await MHMutationWorkflow.runThrowing(
            name: "refreshProjectedDraft",
            operation: {
                // Intentionally empty.
            },
            adapter: adapter,
            projection: .fixedAdapterValue(
                .init(
                    reloadWidgets: true,
                    synchronizeNotifications: true
                )
            ),
            mapFailure: Self.expectedError(from:)
        )

        #expect(await recorder.allValues() == [
            "reloadWidgets",
            "synchronizeNotifications"
        ])
    }

    @Test
    func runThrowing_fixed_adapter_value_maps_operation_failure_with_custom_description() async {
        let operationErrorDescription: @Sendable (any Error) -> String = { _ in
            "displayable failure"
        }

        await #expect(throws: ExpectedError.operation("displayable failure")) {
            try await MHMutationWorkflow.runThrowing(
                name: "saveProjectedDraft",
                operation: {
                    throw OperationTestError.failed
                },
                adapter: MHMutationAdapter<FollowUp>.none,
                projection: .fixedAdapterValue(
                    .init(
                        reloadWidgets: true,
                        synchronizeNotifications: true
                    )
                ),
                mapFailure: Self.expectedError(from:),
                configuration: .init(
                    operationErrorDescription: operationErrorDescription
                )
            )
        }
    }

    @Test
    func runThrowing_projection_maps_step_failure() async {
        let adapter = MHMutationAdapter<FollowUp>.fixed(
            [
                .init(name: "synchronizeNotifications") {
                    throw OperationTestError.failed
                }
            ]
        )

        await #expect(
            throws: ExpectedError.step(
                name: "synchronizeNotifications",
                description: "failed"
            )
        ) {
            try await MHMutationWorkflow.runThrowing(
                name: "saveProjectedDraft",
                operation: { () -> MHMutationProjection<FollowUp, String> in
                    .init(
                        adapterValue: .init(
                            reloadWidgets: true,
                            synchronizeNotifications: true
                        ),
                        resultValue: "saved"
                    )
                },
                adapter: adapter,
                projection: .keyPaths(
                    adapterValue: \MHMutationProjection<FollowUp, String>.adapterValue,
                    resultValue: \MHMutationProjection<FollowUp, String>.resultValue
                ),
                mapFailure: Self.expectedError(from:)
            )
        }
    }

    @Test
    func runThrowing_projection_preserves_cancellation() async {
        await #expect(throws: CancellationError.self) {
            try await MHMutationWorkflow.runThrowing(
                name: "saveProjectedDraft",
                operation: {
                    throw CancellationError()
                },
                adapter: MHMutationAdapter<FollowUp>.none,
                projection: .fixedAdapterValue(
                    .init(
                        reloadWidgets: true,
                        synchronizeNotifications: true
                    )
                ),
                mapFailure: Self.expectedError(from:)
            )
        }
    }
}

private extension MHMutationWorkflowProjectionTests {
    private static func expectedError(from failure: MHMutationFailure) -> ExpectedError {
        switch failure {
        case .operation(let description):
            return .operation(description)
        case let .step(name, errorDescription):
            return .step(
                name: name,
                description: errorDescription
            )
        }
    }

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
