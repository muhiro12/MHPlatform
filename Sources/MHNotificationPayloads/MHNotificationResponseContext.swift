import Foundation

/// Notification response context required for route resolution.
public struct MHNotificationResponseContext: Equatable, Sendable {
    /// Action identifier received from the notification response.
    public let actionIdentifier: String

    /// Identifier representing the default notification tap action.
    public let defaultActionIdentifier: String

    /// Identifier representing the dismiss action.
    public let dismissActionIdentifier: String

    /// Creates a notification response context.
    public init(
        actionIdentifier: String,
        defaultActionIdentifier: String = "com.apple.UNNotificationDefaultActionIdentifier",
        dismissActionIdentifier: String = "com.apple.UNNotificationDismissActionIdentifier"
    ) {
        self.actionIdentifier = actionIdentifier
        self.defaultActionIdentifier = defaultActionIdentifier
        self.dismissActionIdentifier = dismissActionIdentifier
    }
}
