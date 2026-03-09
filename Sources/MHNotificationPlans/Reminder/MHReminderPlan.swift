import Foundation

/// Deterministic reminder plan output.
public struct MHReminderPlan: Sendable {
    /// Unique plan identifier.
    public let identifier: String

    /// Date and time when the reminder should be shown.
    public let notifyDate: Date

    /// Thread identifier used for grouped notifications.
    public let threadIdentifier: String

    /// Badge number for this reminder in sequence.
    public let badgeCount: Int

    /// Remaining days until due date at planning time.
    public let daysUntilDue: Int

    /// Relevance score clamped to a fixed range.
    public let relevanceScore: Double

    /// Reminder title.
    public let title: String

    /// Reminder amount.
    public let amount: Decimal

    /// Reminder due date.
    public let dueDate: Date

    /// Primary route URL.
    public let primaryRouteURL: URL

    /// Secondary route URL.
    public let secondaryRouteURL: URL

    /// Creates a reminder plan.
    public init(
        identifier: String,
        notifyDate: Date,
        threadIdentifier: String,
        badgeCount: Int,
        daysUntilDue: Int,
        relevanceScore: Double,
        title: String,
        amount: Decimal,
        dueDate: Date,
        primaryRouteURL: URL,
        secondaryRouteURL: URL
    ) {
        self.identifier = identifier
        self.notifyDate = notifyDate
        self.threadIdentifier = threadIdentifier
        self.badgeCount = badgeCount
        self.daysUntilDue = daysUntilDue
        self.relevanceScore = relevanceScore
        self.title = title
        self.amount = amount
        self.dueDate = dueDate
        self.primaryRouteURL = primaryRouteURL
        self.secondaryRouteURL = secondaryRouteURL
    }
}
