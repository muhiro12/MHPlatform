import Foundation

/// Shared app-facing workflow shell built on top of `MHMutationRunner`.
public enum MHMutationWorkflow {
    /// Converts an operation error into the string recorded by `MHMutationRunner`.
    public typealias OperationErrorDescription = @Sendable (any Error) -> String
    /// Ordered event callback emitted while running the workflow shell.
    public typealias EventSink<Value: Sendable> = MHMutationRunner.EventSink<Value>

    struct OperationFailure: Error, LocalizedError, CustomStringConvertible, Sendable {
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
    ///
    /// Prefer this overload when the successful operation value should be
    /// returned as-is and only the adapter input is fixed.
    @preconcurrency
    public static func runThrowing<
        OperationValue: Sendable,
        AdapterValue: Sendable
    >(
        name: String,
        operation: @escaping @MainActor @Sendable () throws -> OperationValue,
        adapter: MHMutationAdapter<AdapterValue>,
        adapterValue: AdapterValue,
        onEvent: @escaping EventSink<OperationValue> = { _ in
            // Intentionally empty.
        },
        operationErrorDescription: @escaping OperationErrorDescription = defaultOperationErrorDescription
    ) async throws -> OperationValue {
        try await runThrowing(
            name: name,
            operation: operation,
            adapter: adapter,
            projection: .fixedAdapterValue(adapterValue),
            onEvent: onEvent,
            operationErrorDescription: operationErrorDescription
        )
    }

    /// Runs a main-actor mutation using the default workflow error mapping.
    @preconcurrency
    public static func runThrowing<
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
        operationErrorDescription: @escaping OperationErrorDescription = defaultOperationErrorDescription
    ) async throws -> ResultValue {
        try await runThrowing(
            name: name,
            operation: operation,
            adapter: adapter,
            projection: projection,
            onEvent: onEvent,
            configuration: .init(
                operationErrorDescription: operationErrorDescription
            )
        )
    }

    /// Runs a main-actor mutation with custom workflow failure mapping.
    ///
    /// Prefer this overload when the successful operation value should be
    /// returned as-is and only the adapter input is fixed.
    @preconcurrency
    public static func runThrowing<
        OperationValue: Sendable,
        AdapterValue: Sendable,
        Failure: Error & Sendable
    >(
        name: String,
        operation: @escaping @MainActor @Sendable () throws -> OperationValue,
        adapter: MHMutationAdapter<AdapterValue>,
        adapterValue: AdapterValue,
        mapFailure: @escaping @Sendable (MHMutationFailure) -> Failure,
        onEvent: @escaping EventSink<OperationValue> = { _ in
            // Intentionally empty.
        },
        operationErrorDescription: @escaping OperationErrorDescription = defaultOperationErrorDescription
    ) async throws -> OperationValue {
        try await runThrowing(
            name: name,
            operation: operation,
            adapter: adapter,
            projection: .fixedAdapterValue(adapterValue),
            mapFailure: mapFailure,
            onEvent: onEvent,
            operationErrorDescription: operationErrorDescription
        )
    }

    /// Runs a main-actor mutation with custom workflow failure mapping.
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
        projection: MHMutationProjectionStrategy<
            OperationValue,
            AdapterValue,
            ResultValue
        >,
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
            projection: projection,
            mapFailure: mapFailure,
            onEvent: onEvent,
            configuration: .init(
                operationErrorDescription: operationErrorDescription
            )
        )
    }
}
