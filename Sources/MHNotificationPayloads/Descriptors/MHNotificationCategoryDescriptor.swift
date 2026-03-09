import Foundation

/// A platform-agnostic notification category definition.
public struct MHNotificationCategoryDescriptor: Hashable, Sendable {
    /// Stable category identifier.
    public let identifier: String

    /// Ordered action definitions for this category.
    public let actions: [MHNotificationActionDescriptor]

    /// Creates a notification category descriptor.
    public init(
        identifier: String,
        actions: [MHNotificationActionDescriptor]
    ) {
        self.identifier = identifier
        self.actions = actions
    }
}
