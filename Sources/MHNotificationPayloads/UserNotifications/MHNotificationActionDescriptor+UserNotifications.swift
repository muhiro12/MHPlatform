#if canImport(UserNotifications)
import Foundation
import UserNotifications

public extension MHNotificationActionDescriptor {
    /// Builds a `UNNotificationAction` from this descriptor.
    func makeUNNotificationAction() -> UNNotificationAction {
        let options: UNNotificationActionOptions = opensApp ? [.foreground] : []
        return .init(
            identifier: identifier,
            title: title,
            options: options
        )
    }
}

public extension MHNotificationCategoryDescriptor {
    /// Builds a `UNNotificationCategory` from this descriptor.
    func makeUNNotificationCategory() -> UNNotificationCategory {
        .init(
            identifier: identifier,
            actions: actions.map { action in
                action.makeUNNotificationAction()
            },
            intentIdentifiers: [],
            options: []
        )
    }
}
#endif
