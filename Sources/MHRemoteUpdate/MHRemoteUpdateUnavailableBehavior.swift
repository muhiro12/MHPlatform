/// The app's explicit choice when no validated update decision is available.
public enum MHRemoteUpdateUnavailableBehavior: Equatable, Sendable {
    /// Permit the protected operation without a validated decision.
    case allow
    /// Stop the protected operation until a validated decision is available.
    case block
}
