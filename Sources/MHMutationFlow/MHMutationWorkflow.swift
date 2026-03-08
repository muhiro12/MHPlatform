import Foundation

/// Shared app-facing workflow shell built on top of `MHMutationRunner`.
public enum MHMutationWorkflow {
    /// Converts an operation error into the string recorded by `MHMutationRunner`.
    public typealias OperationErrorDescription = @Sendable (any Error) -> String

    private struct OperationFailure: Error, LocalizedError, CustomStringConvertible, Sendable {
        let description: String

        var errorDescription: String? {
            description
        }
    }

    private struct ProjectedSuccess<AdapterValue: Sendable, ResultValue: Sendable>: Sendable {
        let adapterValue: AdapterValue
        let resultValue: ResultValue
    }

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

    @usableFromInline
    static func defaultOperationErrorDescription(
        _ error: any Error
    ) -> String {
        error.localizedDescription
    }

    /// Runs a main-actor mutation using the default workflow error mapping.
    @preconcurrency
    public static func runThrowing<Value: Sendable>(
        name: String,
        operation: @escaping @MainActor @Sendable () throws -> Value,
        adapter: MHMutationAdapter<Value>,
        operationErrorDescription: @escaping OperationErrorDescription = defaultOperationErrorDescription
    ) async throws -> Value {
        try await runThrowing(
            name: name,
            operation: operation,
            adapter: adapter,
            configuration: .init(
                operationErrorDescription: operationErrorDescription
            )
        )
    }

    /// Runs a main-actor mutation using the returned value directly as adapter input.
    @preconcurrency
    public static func runThrowing<Value: Sendable, Failure: Error & Sendable>(
        name: String,
        operation: @escaping @MainActor @Sendable () throws -> Value,
        adapter: MHMutationAdapter<Value>,
        mapFailure: @escaping @Sendable (MHMutationFailure) -> Failure,
        operationErrorDescription: @escaping OperationErrorDescription = defaultOperationErrorDescription
    ) async throws -> Value {
        try await runThrowing(
            name: name,
            operation: operation,
            adapter: adapter,
            mapFailure: mapFailure,
            configuration: .init(
                operationErrorDescription: operationErrorDescription
            )
        )
    }

    /// Runs a main-actor mutation while projecting adapter input through a key path
    /// and returning the full successful operation value using the default workflow
    /// error mapping.
    @preconcurrency
    public static func runThrowing<
        OperationValue: Sendable,
        AdapterValue: Sendable
    >(
        name: String,
        operation: @escaping @MainActor @Sendable () throws -> OperationValue,
        adapter: MHMutationAdapter<AdapterValue>,
        adapterValue: KeyPath<OperationValue, AdapterValue>,
        operationErrorDescription: @escaping OperationErrorDescription = defaultOperationErrorDescription
    ) async throws -> OperationValue {
        try await runThrowing(
            name: name,
            operation: operation,
            adapter: adapter,
            adapterValue: adapterValue,
            configuration: .init(
                operationErrorDescription: operationErrorDescription
            )
        )
    }

    // swiftlint:disable function_parameter_count
    /// Runs a main-actor mutation while projecting separate adapter input and return value
    /// using the default workflow error mapping.
    @preconcurrency
    public static func runThrowing<
        OperationValue,
        AdapterValue: Sendable,
        ResultValue: Sendable
    >(
        name: String,
        operation: @escaping @MainActor @Sendable () throws -> OperationValue,
        adapter: MHMutationAdapter<AdapterValue>,
        afterSuccess: @escaping @MainActor @Sendable (OperationValue) -> AdapterValue,
        returning: @escaping @MainActor @Sendable (OperationValue) -> ResultValue,
        operationErrorDescription: @escaping OperationErrorDescription = defaultOperationErrorDescription
    ) async throws -> ResultValue {
        try await runThrowing(
            name: name,
            operation: operation,
            adapter: adapter,
            afterSuccess: afterSuccess,
            returning: returning,
            configuration: .init(
                operationErrorDescription: operationErrorDescription
            )
        )
    }

    /// Runs a main-actor mutation while projecting adapter input and return value through
    /// key paths using the default workflow error mapping.
    @preconcurrency
    public static func runThrowing<
        OperationValue,
        AdapterValue: Sendable,
        ResultValue: Sendable
    >(
        name: String,
        operation: @escaping @MainActor @Sendable () throws -> OperationValue,
        adapter: MHMutationAdapter<AdapterValue>,
        adapterValue: KeyPath<OperationValue, AdapterValue>,
        resultValue: KeyPath<OperationValue, ResultValue>,
        operationErrorDescription: @escaping OperationErrorDescription = defaultOperationErrorDescription
    ) async throws -> ResultValue {
        try await runThrowing(
            name: name,
            operation: operation,
            adapter: adapter,
            adapterValue: adapterValue,
            resultValue: resultValue,
            configuration: .init(
                operationErrorDescription: operationErrorDescription
            )
        )
    }

    /// Runs a main-actor mutation while projecting separate adapter input and return value.
    @preconcurrency
    public static func runThrowing<
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
        configuration: MHMutationWorkflowConfiguration
    ) async throws -> ResultValue {
        let mutation = MHMutation.mainActor(name: name) {
            do {
                let value = try operation()
                return ProjectedSuccess(
                    adapterValue: afterSuccess(value),
                    resultValue: returning(value)
                )
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
            adapter: adapter.contramap(\.adapterValue),
            retryPolicy: configuration.retryPolicy,
            cancellationHandle: configuration.cancellationHandle
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

private extension MHMutationWorkflow {
    static func defaultFailure(
        from failure: MHMutationFailure
    ) -> MHMutationWorkflowError {
        .init(failure: failure)
    }
}

public extension MHMutationWorkflow {
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
