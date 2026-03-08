import Foundation

public extension MHMutationWorkflow {
    private static func defaultFailure(
        from failure: MHMutationFailure
    ) -> MHMutationWorkflowError {
        .init(failure: failure)
    }

    /// Runs a main-actor mutation using the default workflow error mapping.
    @preconcurrency
    static func runThrowing<
        OperationValue,
        AdapterValue: Sendable,
        ResultValue: Sendable
    >(
        name: String,
        operation: @escaping @MainActor @Sendable () throws -> OperationValue,
        adapter: MHMutationAdapter<AdapterValue>,
        projection: MHMutationProjectionStrategy<
            OperationValue,
            AdapterValue,
            ResultValue
        >,
        onEvent: @escaping EventSink<ResultValue> = { _ in
            // Intentionally empty.
        },
        configuration: MHMutationWorkflowConfiguration
    ) async throws -> ResultValue {
        try await runThrowing(
            name: name,
            operation: operation,
            adapter: adapter,
            projection: projection,
            mapFailure: defaultFailure(from:),
            onEvent: onEvent,
            configuration: configuration
        )
    }

    // swiftlint:disable function_parameter_count
    /// Runs a main-actor mutation with custom workflow failure mapping.
    @preconcurrency
    static func runThrowing<
        OperationValue,
        AdapterValue: Sendable,
        ResultValue: Sendable,
        Failure: Error & Sendable
    >(
        name: String,
        operation: @escaping @MainActor @Sendable () throws -> OperationValue,
        adapter: MHMutationAdapter<AdapterValue>,
        projection: MHMutationProjectionStrategy<
            OperationValue,
            AdapterValue,
            ResultValue
        >,
        mapFailure: @Sendable (MHMutationFailure) -> Failure,
        onEvent: @escaping EventSink<ResultValue> = { _ in
            // Intentionally empty.
        },
        configuration: MHMutationWorkflowConfiguration
    ) async throws -> ResultValue {
        let mutation = MHMutation.mainActor(name: name) {
            do {
                let value = try operation()
                return projection.project(value)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                throw OperationFailure(
                    description: configuration.operationErrorDescription(error)
                )
            }
        }

        let outcome = await MHMutationRunner.run(
            mutation: mutation,
            adapter: adapter.contramap { (projection: MHMutationProjection<AdapterValue, ResultValue>) in
                projection.adapterValue
            },
            retryPolicy: configuration.retryPolicy,
            cancellationHandle: configuration.cancellationHandle,
            // swiftlint:disable:next trailing_closure
            onEvent: { event in
                onEvent(
                    event.mapValue { (projection: MHMutationProjection<AdapterValue, ResultValue>) in
                        projection.resultValue
                    }
                )
            }
        )

        switch outcome {
        case .succeeded(let value, _, _):
            return value.resultValue
        case .failed(let failure, _, _, _):
            throw mapFailure(failure)
        case .cancelled:
            throw CancellationError()
        }
    }
    // swiftlint:enable function_parameter_count
}
