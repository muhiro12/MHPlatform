import Foundation

/// Shared success carrier for workflows that need separate adapter input and result values.
public struct MHMutationProjection<
    AdapterValue: Sendable,
    ResultValue: Sendable
>: Sendable {
    public let adapterValue: AdapterValue
    public let resultValue: ResultValue

    public init(
        adapterValue: AdapterValue,
        resultValue: ResultValue
    ) {
        self.adapterValue = adapterValue
        self.resultValue = resultValue
    }
}
