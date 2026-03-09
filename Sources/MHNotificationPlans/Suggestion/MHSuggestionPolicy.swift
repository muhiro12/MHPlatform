/// Policy for building deterministic daily suggestion plans.
public struct MHSuggestionPolicy: Sendable {
    /// Notification delivery time.
    public let deliveryTime: MHNotificationTime

    /// Number of future days to plan.
    public let daysAhead: Int

    /// Prefix used when generating plan identifiers.
    public let identifierPrefix: String

    /// Creates a suggestion planning policy.
    public init(
        deliveryTime: MHNotificationTime,
        daysAhead: Int,
        identifierPrefix: String
    ) {
        self.deliveryTime = deliveryTime
        self.daysAhead = daysAhead
        self.identifierPrefix = identifierPrefix
    }
}
