/// Result of a route coordinator operation.
public enum MHRouteResolution<Outcome: Sendable>: Sendable {
    /// The route was resolved and applied immediately.
    case applied(Outcome)
    /// The route was queued as pending.
    case queued
}
