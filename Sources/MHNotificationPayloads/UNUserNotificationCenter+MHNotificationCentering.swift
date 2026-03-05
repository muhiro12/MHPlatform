#if canImport(UserNotifications)
import UserNotifications

extension UNUserNotificationCenter: MHNotificationCentering {
    public func fetchAuthorizationStatus() async -> UNAuthorizationStatus {
        await notificationSettings().authorizationStatus
    }

    public func fetchPendingNotificationRequests() async -> [UNNotificationRequest] {
        await pendingNotificationRequests()
    }

    public func removePendingRequests(withIdentifiers identifiers: [String]) {
        removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    public func registerNotificationCategories(_ categories: Set<UNNotificationCategory>) {
        setNotificationCategories(categories)
    }
}
#endif
