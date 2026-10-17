/// A validated update decision or an explicit absence of sufficient evidence.
public enum MHRemoteUpdateDecision: Equatable, Sendable {
    /// The installed version does not satisfy the active policy.
    case updateRequired
    /// The supplied evidence does not require an update at the evaluated instant.
    case notRequired
    /// A policy, installed version, or required public version could not be validated.
    case unavailable
}
