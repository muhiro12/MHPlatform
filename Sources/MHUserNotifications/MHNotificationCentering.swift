#if canImport(UserNotifications)
import UserNotifications

/// Minimal notification center surface used by orchestration helpers.
public protocol MHNotificationCentering {
    /// Returns the current authorization status.
    @MainActor
    func fetchAuthorizationStatus() async -> UNAuthorizationStatus

    /// Requests notification authorization.
    @MainActor
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool

    /// Returns all pending notification requests.
    @MainActor
    func fetchPendingNotificationRequests() async -> [UNNotificationRequest]

    /// Removes pending requests matching identifiers.
    @MainActor
    func removePendingRequests(withIdentifiers identifiers: [String])

    /// Adds a notification request.
    @MainActor
    func add(_ request: UNNotificationRequest) async throws

    /// Registers notification categories.
    @MainActor
    func registerNotificationCategories(_ categories: Set<UNNotificationCategory>)
}
#endif
