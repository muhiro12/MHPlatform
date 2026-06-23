#if canImport(UserNotifications)
import Foundation

/// Value-typed matcher for identifying notification requests managed by the app.
public struct MHNotificationIdentifierMatcher: Sendable, Equatable {
    public let prefixes: [String]
    public let exactIdentifiers: [String]

    /// Creates a matcher from prefix and exact-identifier lists.
    public init(
        prefixes: [String] = [],
        exactIdentifiers: [String] = []
    ) {
        self.prefixes = prefixes
        self.exactIdentifiers = exactIdentifiers
    }

    /// Returns whether the identifier belongs to the managed request set.
    public func matches(_ identifier: String) -> Bool {
        if exactIdentifiers.contains(identifier) {
            return true
        }

        return prefixes.contains { prefix in
            identifier.hasPrefix(prefix)
        }
    }
}
#endif
