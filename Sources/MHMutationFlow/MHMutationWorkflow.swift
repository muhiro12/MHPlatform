import Foundation

/// Shared app-facing workflow shell built on top of `MHMutationRunner`.
public enum MHMutationWorkflow {
    /// Converts an operation error into the string recorded by `MHMutationRunner`.
    public typealias OperationErrorDescription = @Sendable (any Error) -> String
    /// Ordered event callback emitted while running the workflow shell.
    public typealias EventSink<Value: Sendable> = MHMutationRunner.EventSink<Value>

    private struct OperationFailure: Error, LocalizedError, CustomStringConvertible, Sendable {
        let description: String

        var errorDescription: String? {
            description
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
        onEvent: @escaping EventSink<Value> = { _ in
            // Intentionally empty.
        },
        operationErrorDescription: @escaping OperationErrorDescription = defaultOperationErrorDescription
    ) async throws -> Value {
        try await runThrowing(
            name: name,
            operation: operation,
            adapter: adapter,
            onEvent: onEvent,
            configuration: .init(
                operationErrorDescription: operationErrorDescription
            )
        )
    }

    /// Runs a main-actor mutation whose operation already returns separate adapter and result values.
    @preconcurrency
    public static func runThrowing<
        AdapterValue: Sendable,
        ResultValue: Sendable
    >(
        name: String,
        operation: @escaping @MainActor @Sendable () throws -> MHMutationProjection<AdapterValue, ResultValue>,
        adapter: MHMutationAdapter<AdapterValue>,
        onEvent: @escaping EventSink<ResultValue> = { _ in
            // Intentionally empty.
        },
        operationErrorDescription: @escaping OperationErrorDescription = defaultOperationErrorDescription
    ) async throws -> ResultValue {
        try await runThrowing(
            name: name,
            operation: operation,
            adapter: adapter,
            onEvent: onEvent,
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
        onEvent: @escaping EventSink<Value> = { _ in
            // Intentionally empty.
        },
        operationErrorDescription: @escaping OperationErrorDescription = defaultOperationErrorDescription
    ) async throws -> Value {
        try await runThrowing(
            name: name,
            operation: operation,
            adapter: adapter,
            mapFailure: mapFailure,
            onEvent: onEvent,
            configuration: .init(
                operationErrorDescription: operationErrorDescription
            )
        )
    }

    /// Runs a main-actor mutation whose operation already returns separate adapter and result values.
    @preconcurrency
    public static func runThrowing<
        AdapterValue: Sendable,
        ResultValue: Sendable,
        Failure: Error & Sendable
    >(
        name: String,
        operation: @escaping @MainActor @Sendable () throws -> MHMutationProjection<AdapterValue, ResultValue>,
        adapter: MHMutationAdapter<AdapterValue>,
        mapFailure: @escaping @Sendable (MHMutationFailure) -> Failure,
        onEvent: @escaping EventSink<ResultValue> = { _ in
            // Intentionally empty.
        },
        operationErrorDescription: @escaping OperationErrorDescription = defaultOperationErrorDescription
    ) async throws -> ResultValue {
        try await runThrowing(
            name: name,
            operation: operation,
            adapter: adapter,
            mapFailure: mapFailure,
            onEvent: onEvent,
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
        onEvent: @escaping EventSink<OperationValue> = { _ in
            // Intentionally empty.
        },
        operationErrorDescription: @escaping OperationErrorDescription = defaultOperationErrorDescription
    ) async throws -> OperationValue {
        try await runThrowing(
            name: name,
            operation: operation,
            adapter: adapter,
            adapterValue: adapterValue,
            onEvent: onEvent,
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
        onEvent: @escaping EventSink<ResultValue> = { _ in
            // Intentionally empty.
        },
        operationErrorDescription: @escaping OperationErrorDescription = defaultOperationErrorDescription
    ) async throws -> ResultValue {
        try await runThrowing(
            name: name,
            operation: operation,
            adapter: adapter,
            afterSuccess: afterSuccess,
            returning: returning,
            onEvent: onEvent,
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
        onEvent: @escaping EventSink<ResultValue> = { _ in
            // Intentionally empty.
        },
        operationErrorDescription: @escaping OperationErrorDescription = defaultOperationErrorDescription
    ) async throws -> ResultValue {
        try await runThrowing(
            name: name,
            operation: operation,
            adapter: adapter,
            adapterValue: adapterValue,
            resultValue: resultValue,
            onEvent: onEvent,
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
        onEvent: @escaping EventSink<ResultValue> = { _ in
            // Intentionally empty.
        },
        configuration: MHMutationWorkflowConfiguration
    ) async throws -> ResultValue {
        let mutation = MHMutation.mainActor(name: name) {
            do {
                let value = try operation()
                return MHMutationProjection(
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
            cancellationHandle: configuration.cancellationHandle,
            // swiftlint:disable:next trailing_closure
            onEvent: { event in
                onEvent(
                    event.mapValue { projection in
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
