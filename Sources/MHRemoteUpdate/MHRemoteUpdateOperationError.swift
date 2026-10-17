/// A failed update precondition, ready for app-owned error mapping or presentation.
public enum MHRemoteUpdateOperationError: Error, Equatable, Sendable {
    /// An active policy requires an update.
    case updateRequired
    /// No validated decision is available and the app selected blocking behavior.
    case policyUnavailable
}
