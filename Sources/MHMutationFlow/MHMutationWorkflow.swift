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
            mapFailure: defaultFailure(from:),
            operationErrorDescription: operationErrorDescription
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
            afterSuccess: { value in
                value
            },
            returning: { value in
                value
            },
            mapFailure: mapFailure,
            operationErrorDescription: operationErrorDescription
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
            mapFailure: defaultFailure(from:),
            operationErrorDescription: operationErrorDescription
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
        operationErrorDescription: @escaping OperationErrorDescription = defaultOperationErrorDescription
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
                    description: operationErrorDescription(error)
                )
            }
        }

        let outcome = await MHMutationRunner.run(
            mutation: mutation,
            adapter: adapter.contramap(\.adapterValue)
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
