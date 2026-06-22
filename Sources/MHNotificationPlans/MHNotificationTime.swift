import Foundation

/// Notification delivery time represented as hour and minute.
public struct MHNotificationTime: Equatable, Sendable {
    private enum Constants {
        static let hourUpperBound = 24
        static let minuteUpperBound = 60
    }

    /// Delivery hour in 24-hour format.
    public let hour: Int

    /// Delivery minute.
    public let minute: Int

    /// Creates a validated delivery time.
    public init?(
        hour: Int,
        minute: Int
    ) {
        let hasValidHour = (0..<Constants.hourUpperBound).contains(hour)
        let hasValidMinute = (0..<Constants.minuteUpperBound).contains(minute)

        guard hasValidHour, hasValidMinute else {
            return nil
        }

        self.hour = hour
        self.minute = minute
    }
}
