#if canImport(UserNotifications)
import UserNotifications

extension UNUserNotificationCenter: MHNotificationCentering {
    @preconcurrency
    @MainActor
    public func fetchAuthorizationStatus() async -> UNAuthorizationStatus {
        await notificationSettings().authorizationStatus
    }

    @preconcurrency
    @MainActor
    public func fetchPendingNotificationRequests() async -> [UNNotificationRequest] {
        await pendingNotificationRequests()
    }

    @preconcurrency
    @MainActor
    public func removePendingRequests(withIdentifiers identifiers: [String]) {
        removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    @preconcurrency
    @MainActor
    public func registerNotificationCategories(_ categories: Set<UNNotificationCategory>) {
        setNotificationCategories(categories)
    }
}
#endif
