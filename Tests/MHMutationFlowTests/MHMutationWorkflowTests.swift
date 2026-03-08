import MHMutationFlow
import Testing

struct MHMutationWorkflowTests {
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

    private enum ExpectedError: Error, Equatable, Sendable {
        case operation(String)
        case step(name: String, description: String)
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
            adapter: adapter,
            projection: .identity,
            mapFailure: Self.expectedError(from:)
        )

        #expect(result == "saved")
        #expect(await recorder.allValues() == [
            "reloadWidgets",
            "synchronizeNotifications"
        ])
    }

    @Test
    func runThrowing_projects_closure_projection_and_return_value() async throws {
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
            projection: .closures(
                afterSuccess: { (wrappedValue: WrappedValue) in
                    wrappedValue.followUp
                },
                returning: { (wrappedValue: WrappedValue) in
                    wrappedValue.value
                }
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
    func runThrowing_maps_operation_failure_with_custom_description() async {
        let operationErrorDescription: @Sendable (any Error) -> String = { _ in
            "displayable failure"
        }

        await #expect(throws: ExpectedError.operation("displayable failure")) {
            try await MHMutationWorkflow.runThrowing(
                name: "saveDraft",
                operation: {
                    throw OperationTestError.failed
                },
                adapter: MHMutationAdapter<String>.none,
                projection: .identity,
                mapFailure: Self.expectedError(from:),
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
            throws: ExpectedError.step(
                name: "synchronizeNotifications",
                description: "failed"
            )
        ) {
            try await MHMutationWorkflow.runThrowing(
                name: "saveDraft",
                operation: {
                    "saved"
                },
                adapter: adapter,
                projection: .identity,
                mapFailure: Self.expectedError(from:)
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
                adapter: MHMutationAdapter<String>.none,
                projection: .identity,
                mapFailure: Self.expectedError(from:)
            )
        }
    }
}

private extension MHMutationWorkflowTests {
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
}
