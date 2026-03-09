import Foundation

/// Shared workflow configuration for retry, cancellation, and operation failure
/// mapping.
public struct MHMutationWorkflowConfiguration: Sendable {
    public let retryPolicy: MHMutationRetryPolicy
    public let cancellationHandle: MHCancellationHandle?
    public let operationErrorDescription: MHMutationWorkflow.OperationErrorDescription

    /// Creates a workflow configuration with narrow defaults.
    public init(
        retryPolicy: MHMutationRetryPolicy = .none,
        cancellationHandle: MHCancellationHandle? = nil,
        operationErrorDescription: @escaping MHMutationWorkflow.OperationErrorDescription = \.localizedDescription
    ) {
        self.retryPolicy = retryPolicy
        self.cancellationHandle = cancellationHandle
        self.operationErrorDescription = operationErrorDescription
    }
}
