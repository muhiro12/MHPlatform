import Foundation

/// A platform-agnostic notification action definition.
public struct MHNotificationActionDescriptor: Hashable, Sendable {
    /// Stable action identifier delivered by the notification response.
    public let identifier: String

    /// User-visible action title.
    public let title: String

    /// Whether selecting this action should open the app.
    public let opensApp: Bool

    /// Creates a notification action descriptor.
    public init(
        identifier: String,
        title: String,
        opensApp: Bool = true
    ) {
        self.identifier = identifier
        self.title = title
        self.opensApp = opensApp
    }
}
