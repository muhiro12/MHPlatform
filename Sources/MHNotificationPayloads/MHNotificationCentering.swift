#if canImport(UserNotifications)
import UserNotifications

/// Minimal notification center surface used by orchestration helpers.
public protocol MHNotificationCentering {
    /// Returns the current authorization status.
    func fetchAuthorizationStatus() async -> UNAuthorizationStatus

    /// Requests notification authorization.
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool

    /// Returns all pending notification requests.
    func fetchPendingNotificationRequests() async -> [UNNotificationRequest]

    /// Removes pending requests matching identifiers.
    func removePendingRequests(withIdentifiers identifiers: [String])

    /// Adds a notification request.
    func add(_ request: UNNotificationRequest) async throws

    /// Registers notification categories.
    func registerNotificationCategories(_ categories: Set<UNNotificationCategory>)
}
#endif
