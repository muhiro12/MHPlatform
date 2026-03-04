import Foundation

/// Notification delivery time represented as hour and minute.
public struct MHNotificationTime: Equatable, Sendable {
    /// Delivery hour in 24-hour format.
    public let hour: Int

    /// Delivery minute.
    public let minute: Int

    /// Creates a validated delivery time.
    public init?(
        hour: Int,
        minute: Int
    ) {
        // swiftlint:disable:next no_magic_numbers
        let hasValidHour = (0..<24).contains(hour)
        // swiftlint:disable:next no_magic_numbers
        let hasValidMinute = (0..<60).contains(minute)

        guard hasValidHour, hasValidMinute else {
            return nil
        }

        self.hour = hour
        self.minute = minute
    }
}
