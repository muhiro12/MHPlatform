/// Outcome of route submission or pending-route application.
public enum MHRouteExecutionOutcome<Outcome: Sendable>: Sendable {
    /// The route was resolved and applied immediately.
    case applied(Outcome)

    /// The route was queued as pending because execution was not possible yet.
    case queued

    /// The route was ignored because it matched the current pending route.
    case deduplicated
}
