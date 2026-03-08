import Foundation

public extension MHMutationWorkflow {
    private struct AdapterValueProjection<OperationValue, AdapterValue: Sendable>: @unchecked Sendable {
        let keyPath: KeyPath<OperationValue, AdapterValue>

        func project(_ operationValue: OperationValue) -> AdapterValue {
            operationValue[keyPath: keyPath]
        }
    }

    private struct ProjectedValueExtraction<
        OperationValue,
        AdapterValue: Sendable,
        ResultValue: Sendable
    >: @unchecked Sendable {
        let adapterValue: KeyPath<OperationValue, AdapterValue>
        let resultValue: KeyPath<OperationValue, ResultValue>

        func projectedAdapterValue(
            from operationValue: OperationValue
        ) -> AdapterValue {
            operationValue[keyPath: adapterValue]
        }

        func projectedResultValue(
            from operationValue: OperationValue
        ) -> ResultValue {
            operationValue[keyPath: resultValue]
        }
    }

    private static func defaultFailure(
        from failure: MHMutationFailure
    ) -> MHMutationWorkflowError {
        .init(failure: failure)
    }

    /// Runs a main-actor mutation using the default workflow error mapping.
    @preconcurrency
    static func runThrowing<Value: Sendable>(
        name: String,
        operation: @escaping @MainActor @Sendable () throws -> Value,
        adapter: MHMutationAdapter<Value>,
        configuration: MHMutationWorkflowConfiguration
    ) async throws -> Value {
        try await runThrowing(
            name: name,
            operation: operation,
            adapter: adapter,
            mapFailure: defaultFailure(from:),
            configuration: configuration
        )
    }

    /// Runs a main-actor mutation whose operation already returns separate adapter and result values.
    @preconcurrency
    static func runThrowing<
        AdapterValue: Sendable,
        ResultValue: Sendable
    >(
        name: String,
        operation: @escaping @MainActor @Sendable () throws -> MHMutationProjection<AdapterValue, ResultValue>,
        adapter: MHMutationAdapter<AdapterValue>,
        configuration: MHMutationWorkflowConfiguration
    ) async throws -> ResultValue {
        try await runThrowing(
            name: name,
            operation: operation,
            adapter: adapter,
            mapFailure: defaultFailure(from:),
            configuration: configuration
        )
    }

    /// Runs a main-actor mutation using the returned value directly as adapter input.
    @preconcurrency
    static func runThrowing<Value: Sendable, Failure: Error & Sendable>(
        name: String,
        operation: @escaping @MainActor @Sendable () throws -> Value,
        adapter: MHMutationAdapter<Value>,
        mapFailure: @escaping @Sendable (MHMutationFailure) -> Failure,
        configuration: MHMutationWorkflowConfiguration
    ) async throws -> Value {
        try await runThrowing(
            name: name,
            operation: operation,
            adapter: adapter,
            afterSuccess: { value in
                value
            },
            returning: { value in
                value
            },
            mapFailure: mapFailure,
            configuration: configuration
        )
    }

    /// Runs a main-actor mutation whose operation already returns separate adapter and result values.
    @preconcurrency
    static func runThrowing<
        AdapterValue: Sendable,
        ResultValue: Sendable,
        Failure: Error & Sendable
    >(
        name: String,
        operation: @escaping @MainActor @Sendable () throws -> MHMutationProjection<AdapterValue, ResultValue>,
        adapter: MHMutationAdapter<AdapterValue>,
        mapFailure: @escaping @Sendable (MHMutationFailure) -> Failure,
        configuration: MHMutationWorkflowConfiguration
    ) async throws -> ResultValue {
        try await runThrowing(
            name: name,
            operation: operation,
            adapter: adapter,
            afterSuccess: { projection in
                projection.adapterValue
            },
            returning: { projection in
                projection.resultValue
            },
            mapFailure: mapFailure,
            configuration: configuration
        )
    }

    /// Runs a main-actor mutation while projecting adapter input through a key path
    /// and returning the full successful operation value.
    @preconcurrency
    static func runThrowing<
        OperationValue: Sendable,
        AdapterValue: Sendable
    >(
        name: String,
        operation: @escaping @MainActor @Sendable () throws -> OperationValue,
        adapter: MHMutationAdapter<AdapterValue>,
        adapterValue: KeyPath<OperationValue, AdapterValue>,
        configuration: MHMutationWorkflowConfiguration
    ) async throws -> OperationValue {
        let projection = AdapterValueProjection(keyPath: adapterValue)

        return try await runThrowing(
            name: name,
            operation: operation,
            adapter: adapter,
            afterSuccess: { operationValue in
                projection.project(operationValue)
            },
            returning: { operationValue in
                operationValue
            },
            configuration: configuration
        )
    }

    // swiftlint:disable function_parameter_count
    /// Runs a main-actor mutation while projecting separate adapter input and return value.
    @preconcurrency
    static func runThrowing<
        OperationValue,
        AdapterValue: Sendable,
        ResultValue: Sendable
    >(
        name: String,
        operation: @escaping @MainActor @Sendable () throws -> OperationValue,
        adapter: MHMutationAdapter<AdapterValue>,
        afterSuccess: @escaping @MainActor @Sendable (OperationValue) -> AdapterValue,
        returning: @escaping @MainActor @Sendable (OperationValue) -> ResultValue,
        configuration: MHMutationWorkflowConfiguration
    ) async throws -> ResultValue {
        try await runThrowing(
            name: name,
            operation: operation,
            adapter: adapter,
            afterSuccess: afterSuccess,
            returning: returning,
            mapFailure: defaultFailure(from:),
            configuration: configuration
        )
    }

    /// Runs a main-actor mutation while projecting adapter input and return value through
    /// key paths.
    @preconcurrency
    static func runThrowing<
        OperationValue,
        AdapterValue: Sendable,
        ResultValue: Sendable
    >(
        name: String,
        operation: @escaping @MainActor @Sendable () throws -> OperationValue,
        adapter: MHMutationAdapter<AdapterValue>,
        adapterValue: KeyPath<OperationValue, AdapterValue>,
        resultValue: KeyPath<OperationValue, ResultValue>,
        configuration: MHMutationWorkflowConfiguration
    ) async throws -> ResultValue {
        let extraction = ProjectedValueExtraction(
            adapterValue: adapterValue,
            resultValue: resultValue
        )

        return try await runThrowing(
            name: name,
            operation: operation,
            adapter: adapter,
            afterSuccess: { operationValue in
                extraction.projectedAdapterValue(from: operationValue)
            },
            returning: { operationValue in
                extraction.projectedResultValue(from: operationValue)
            },
            configuration: configuration
        )
    }

    /// Runs a main-actor mutation while projecting separate adapter input and return value.
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
        afterSuccess: @escaping @MainActor @Sendable (OperationValue) -> AdapterValue,
        returning: @escaping @MainActor @Sendable (OperationValue) -> ResultValue,
        mapFailure: @Sendable (MHMutationFailure) -> Failure,
        operationErrorDescription: @escaping OperationErrorDescription = defaultOperationErrorDescription
    ) async throws -> ResultValue {
        try await runThrowing(
            name: name,
            operation: operation,
            adapter: adapter,
            afterSuccess: afterSuccess,
            returning: returning,
            mapFailure: mapFailure,
            configuration: .init(
                operationErrorDescription: operationErrorDescription
            )
        )
    }
    // swiftlint:enable function_parameter_count
}
