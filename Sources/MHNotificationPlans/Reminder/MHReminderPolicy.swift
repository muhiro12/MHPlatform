import Foundation

/// Policy for building due-date reminder plans.
public struct MHReminderPolicy: Sendable {
    /// Enables or disables reminder planning.
    public let isEnabled: Bool

    /// Candidates below this amount are ignored.
    public let minimumAmount: Decimal

    /// Lead days before due date for scheduling.
    public let daysBeforeDueDate: Int

    /// Notification delivery time.
    public let deliveryTime: MHNotificationTime

    /// Prefix used when building plan identifiers.
    public let identifierPrefix: String

    /// Optional maximum number of planned reminders.
    public let maximumCount: Int?

    /// Creates a reminder planning policy.
    public init(
        isEnabled: Bool,
        minimumAmount: Decimal,
        daysBeforeDueDate: Int,
        deliveryTime: MHNotificationTime,
        identifierPrefix: String,
        maximumCount: Int? = nil
    ) {
        self.isEnabled = isEnabled
        self.minimumAmount = minimumAmount
        self.daysBeforeDueDate = daysBeforeDueDate
        self.deliveryTime = deliveryTime
        self.identifierPrefix = identifierPrefix
        self.maximumCount = maximumCount
    }
}
