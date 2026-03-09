#if canImport(UserNotifications)
import Foundation
import UserNotifications

/// Shared orchestration helpers for notification-center workflows.
public enum MHNotificationOrchestrator {
    /// Registers categories on the notification center.
    @MainActor
    @preconcurrency
    public static func registerCategories(
        _ categoryDescriptors: [MHNotificationCategoryDescriptor],
        center: any MHNotificationCentering
    ) {
        center.registerNotificationCategories(
            Set(categoryDescriptors.map { descriptor in
                descriptor.makeUNNotificationCategory()
            })
        )
    }

    /// Requests authorization only when current status is `.notDetermined`.
    @MainActor
    @preconcurrency
    public static func requestAuthorizationIfNeeded(
        center: any MHNotificationCentering,
        options: UNAuthorizationOptions,
        requestIfNotDetermined: Bool = true
    ) async -> UNAuthorizationStatus {
        let currentStatus = await center.fetchAuthorizationStatus()
        guard requestIfNotDetermined, currentStatus == .notDetermined else {
            return currentStatus
        }

        _ = try? await center.requestAuthorization(options: options)
        return await center.fetchAuthorizationStatus()
    }

    /// Syncs managed pending requests and returns partial success details.
    @MainActor
    @preconcurrency
    public static func replaceManagedPendingRequests(
        center: any MHNotificationCentering,
        requests: [UNNotificationRequest],
        matcher: MHNotificationIdentifierMatcher
    ) async -> MHNotificationRequestSyncOutcome {
        await replaceManagedPendingRequests(
            center: center,
            requests: requests
        ) { identifier in
            matcher.matches(identifier)
        }
    }

    /// Syncs managed pending requests and returns partial success details.
    @MainActor
    @preconcurrency
    public static func replaceManagedPendingRequests(
        center: any MHNotificationCentering,
        requests: [UNNotificationRequest],
        isManagedIdentifier: @Sendable (String) -> Bool
    ) async -> MHNotificationRequestSyncOutcome {
        let pendingRequests = await center.fetchPendingNotificationRequests()
        let managedPendingIdentifiers = pendingRequests
            .map(\.identifier)
            .filter(isManagedIdentifier)
        let managedRequestIdentifiers = Set(requests.map(\.identifier))
        let removedPendingIdentifiers = managedPendingIdentifiers
            .filter { identifier in
                managedRequestIdentifiers.contains(identifier) == false
            }
            .sorted()

        if removedPendingIdentifiers.isEmpty == false {
            center.removePendingRequests(withIdentifiers: removedPendingIdentifiers)
        }

        var addedRequestIdentifiers = [String]()
        var failedRequestIdentifiers = [String]()

        for request in requests {
            do {
                try await center.add(request)
                addedRequestIdentifiers.append(request.identifier)
            } catch {
                failedRequestIdentifiers.append(request.identifier)
            }
        }

        return .init(
            removedPendingIdentifiers: removedPendingIdentifiers,
            addedRequestIdentifiers: addedRequestIdentifiers,
            failedRequestIdentifiers: failedRequestIdentifiers
        )
    }
}
#endif
