#if canImport(UserNotifications)
import Foundation

/// Outcome of replacing managed pending notification requests.
public struct MHNotificationRequestSyncOutcome: Sendable, Equatable {
    /// Pending request identifiers removed before scheduling.
    public let removedPendingIdentifiers: [String]

    /// Request identifiers added successfully.
    public let addedRequestIdentifiers: [String]

    /// Request identifiers that failed to add.
    public let failedRequestIdentifiers: [String]

    /// Creates a sync outcome.
    public init(
        removedPendingIdentifiers: [String],
        addedRequestIdentifiers: [String],
        failedRequestIdentifiers: [String]
    ) {
        self.removedPendingIdentifiers = removedPendingIdentifiers
        self.addedRequestIdentifiers = addedRequestIdentifiers
        self.failedRequestIdentifiers = failedRequestIdentifiers
    }
}
#endif
