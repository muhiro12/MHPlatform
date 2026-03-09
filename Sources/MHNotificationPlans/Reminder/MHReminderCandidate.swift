import Foundation

/// Input candidate used when building due-date reminder plans.
public struct MHReminderCandidate: Sendable {
    /// Stable identifier used in generated plan identifiers.
    public let stableIdentifier: String

    /// Display title for the reminder.
    public let title: String

    /// Monetary amount associated with this reminder.
    public let amount: Decimal

    /// Due date used for schedule calculation.
    public let dueDate: Date

    /// Primary navigation URL for reminder actions.
    public let primaryRouteURL: URL

    /// Secondary navigation URL for fallback actions.
    public let secondaryRouteURL: URL

    /// Creates a reminder candidate.
    public init(
        stableIdentifier: String,
        title: String,
        amount: Decimal,
        dueDate: Date,
        primaryRouteURL: URL,
        secondaryRouteURL: URL
    ) {
        self.stableIdentifier = stableIdentifier
        self.title = title
        self.amount = amount
        self.dueDate = dueDate
        self.primaryRouteURL = primaryRouteURL
        self.secondaryRouteURL = secondaryRouteURL
    }
}
