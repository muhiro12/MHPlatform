import Foundation

/// Defines how a successful mutation value becomes adapter input and workflow result.
public struct MHMutationProjectionStrategy<
    OperationValue,
    AdapterValue: Sendable,
    ResultValue: Sendable
>: @unchecked Sendable {
    private struct KeyPathProjection: @unchecked Sendable {
        let adapterValue: KeyPath<OperationValue, AdapterValue>
        let resultValue: KeyPath<OperationValue, ResultValue>

        func project(
            _ operationValue: OperationValue
        ) -> MHMutationProjection<AdapterValue, ResultValue> {
            .init(
                adapterValue: operationValue[keyPath: adapterValue],
                resultValue: operationValue[keyPath: resultValue]
            )
        }
    }

    private let projector: @MainActor @Sendable (OperationValue) -> MHMutationProjection<AdapterValue, ResultValue>

    @preconcurrency
    public init(
        projector: @escaping @MainActor @Sendable (OperationValue) -> MHMutationProjection<AdapterValue, ResultValue>
    ) {
        self.projector = projector
    }

    public static func keyPaths(
        adapterValue: KeyPath<OperationValue, AdapterValue>,
        resultValue: KeyPath<OperationValue, ResultValue>
    ) -> Self {
        let projection = KeyPathProjection(
            adapterValue: adapterValue,
            resultValue: resultValue
        )

        return .init { operationValue in
            projection.project(operationValue)
        }
    }

    @preconcurrency
    public static func closures(
        afterSuccess: @escaping @MainActor @Sendable (OperationValue) -> AdapterValue,
        returning: @escaping @MainActor @Sendable (OperationValue) -> ResultValue
    ) -> Self {
        .init { operationValue in
            .init(
                adapterValue: afterSuccess(operationValue),
                resultValue: returning(operationValue)
            )
        }
    }

    @preconcurrency
    @MainActor
    public func project(
        _ operationValue: OperationValue
    ) -> MHMutationProjection<AdapterValue, ResultValue> {
        projector(operationValue)
    }
}

public extension MHMutationProjectionStrategy
where
    OperationValue: Sendable,
    AdapterValue == OperationValue,
    ResultValue == OperationValue {
    /// Uses the successful value for both adapter input and returned result.
    static var identity: Self {
        .init { operationValue in
            .init(
                adapterValue: operationValue,
                resultValue: operationValue
            )
        }
    }
}

public extension MHMutationProjectionStrategy
where
    OperationValue: Sendable,
    ResultValue == OperationValue {
    /// Uses a fixed adapter input while returning the successful operation value.
    static func fixedAdapterValue(
        _ adapterValue: AdapterValue
    ) -> Self {
        .init { operationValue in
            .init(
                adapterValue: adapterValue,
                resultValue: operationValue
            )
        }
    }
}
