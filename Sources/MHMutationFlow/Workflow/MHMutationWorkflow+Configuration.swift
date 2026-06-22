import Foundation

public extension MHMutationWorkflow {
    struct RunOptions<Value: Sendable>: Sendable {
        let onEvent: EventSink<Value>
        let configuration: MHMutationWorkflowConfiguration

        public init(
            configuration: MHMutationWorkflowConfiguration
        ) {
            self.init(
                onEvent: { _ in
                    // Intentionally empty.
                },
                configuration: configuration
            )
        }

        public init(
            onEvent: @escaping EventSink<Value>,
            configuration: MHMutationWorkflowConfiguration
        ) {
            self.onEvent = onEvent
            self.configuration = configuration
        }
    }

    struct FailureOptions<
        Value: Sendable,
        Failure: Error & Sendable
    >: Sendable {
        let mapFailure: @Sendable (MHMutationFailure) -> Failure
        let onEvent: EventSink<Value>
        let configuration: MHMutationWorkflowConfiguration

        @preconcurrency
        public init(
            mapFailure: @escaping @Sendable (MHMutationFailure) -> Failure,
            configuration: MHMutationWorkflowConfiguration
        ) {
            self.init(
                mapFailure: mapFailure,
                onEvent: { _ in
                    // Intentionally empty.
                },
                configuration: configuration
            )
        }

        @preconcurrency
        public init(
            mapFailure: @escaping @Sendable (MHMutationFailure) -> Failure,
            onEvent: @escaping EventSink<Value>,
            configuration: MHMutationWorkflowConfiguration
        ) {
            self.mapFailure = mapFailure
            self.onEvent = onEvent
            self.configuration = configuration
        }
    }

    private static func defaultFailure(
        from failure: MHMutationFailure
    ) -> MHMutationWorkflowError {
        .init(failure: failure)
    }

    /// Runs a main-actor mutation using the default workflow error mapping.
    @preconcurrency
    static func runThrowing<
        OperationValue: Sendable,
        AdapterValue: Sendable
    >(
        name: String,
        operation: @escaping @MainActor @Sendable () throws -> OperationValue,
        adapter: MHMutationAdapter<AdapterValue>,
        adapterValue: AdapterValue,
        options: RunOptions<OperationValue>
    ) async throws -> OperationValue {
        try await runThrowing(
            name: name,
            operation: operation,
            adapter: adapter,
            projection: .fixedAdapterValue(adapterValue),
            options: options
        )
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
        options: RunOptions<ResultValue>
    ) async throws -> ResultValue {
        try await runThrowing(
            name: name,
            operation: operation,
            adapter: adapter,
            projection: projection,
            options: .init(
                mapFailure: defaultFailure(from:),
                onEvent: options.onEvent,
                configuration: options.configuration
            )
        )
    }

    /// Runs a main-actor mutation with custom workflow failure mapping.
    @preconcurrency
    static func runThrowing<
        OperationValue: Sendable,
        AdapterValue: Sendable,
        Failure: Error & Sendable
    >(
        name: String,
        operation: @escaping @MainActor @Sendable () throws -> OperationValue,
        adapter: MHMutationAdapter<AdapterValue>,
        adapterValue: AdapterValue,
        options: FailureOptions<OperationValue, Failure>
    ) async throws -> OperationValue {
        try await runThrowing(
            name: name,
            operation: operation,
            adapter: adapter,
            projection: .fixedAdapterValue(adapterValue),
            options: .init(
                mapFailure: options.mapFailure,
                onEvent: options.onEvent,
                configuration: options.configuration
            )
        )
    }

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
        options: FailureOptions<ResultValue, Failure>
    ) async throws -> ResultValue {
        let mutation = MHMutation.mainActor(name: name) {
            do {
                let value = try operation()
                return projection.project(value)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                throw OperationFailure(
                    description: options.configuration.operationErrorDescription(error)
                )
            }
        }

        let eventSink: MHMutationRunner.EventSink<
            MHMutationProjection<AdapterValue, ResultValue>
        > = { event in
            options.onEvent(
                event.mapValue { (projection: MHMutationProjection<AdapterValue, ResultValue>) in
                    projection.resultValue
                }
            )
        }

        let outcome = await MHMutationRunner.run(
            mutation: mutation,
            adapter: adapter.contramap { (projection: MHMutationProjection<AdapterValue, ResultValue>) in
                projection.adapterValue
            },
            retryPolicy: options.configuration.retryPolicy,
            cancellationHandle: options.configuration.cancellationHandle,
            onEvent: eventSink
        )

        switch outcome {
        case .succeeded(let value, _, _):
            return value.resultValue
        case .failed(let failure, _, _, _):
            throw options.mapFailure(failure)
        case .cancelled:
            throw CancellationError()
        }
    }
}
