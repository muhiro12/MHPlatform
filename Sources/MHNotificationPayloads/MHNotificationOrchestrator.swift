#if canImport(UserNotifications)
import Foundation
import UserNotifications

/// Shared orchestration helpers for notification-center workflows.
public enum MHNotificationOrchestrator {
    /// Registers categories on the notification center.
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

    /// Replaces managed pending requests and returns partial success details.
    @preconcurrency
    public static func replaceManagedPendingRequests(
        center: any MHNotificationCentering,
        requests: [UNNotificationRequest],
        isManagedIdentifier: @Sendable (String) -> Bool
    ) async -> MHNotificationRequestSyncResult {
        let pendingRequests = await center.fetchPendingNotificationRequests()
        let removedPendingIdentifiers = pendingRequests
            .map(\.identifier)
            .filter(isManagedIdentifier)
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

    /// Resolves a route URL directly from userInfo and action identifier.
    public static func resolveRouteURL(
        userInfo: [AnyHashable: Any],
        actionIdentifier: String,
        codec: MHNotificationPayloadCodec = .init(),
        defaultActionIdentifier: String = "com.apple.UNNotificationDefaultActionIdentifier",
        dismissActionIdentifier: String = "com.apple.UNNotificationDismissActionIdentifier"
    ) -> URL? {
        guard let payload = codec.decode(userInfo) else {
            return nil
        }

        return MHNotificationRouteResolver.resolveRouteURL(
            payload: payload,
            response: .init(
                actionIdentifier: actionIdentifier,
                defaultActionIdentifier: defaultActionIdentifier,
                dismissActionIdentifier: dismissActionIdentifier
            )
        )
    }
}
#endif
