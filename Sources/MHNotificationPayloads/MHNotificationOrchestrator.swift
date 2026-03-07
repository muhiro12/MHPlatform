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

    /// Resolves a route URL directly from userInfo and action identifier.
    public static func resolveRouteURL(
        userInfo: [AnyHashable: Any],
        actionIdentifier: String,
        codec: MHNotificationPayloadCodec = .init(),
        defaultActionIdentifier: String = "com.apple.UNNotificationDefaultActionIdentifier",
        dismissActionIdentifier: String = "com.apple.UNNotificationDismissActionIdentifier"
    ) -> URL? {
        resolveRouteURL(
            payload: codec.decode(userInfo),
            response: .init(
                actionIdentifier: actionIdentifier,
                defaultActionIdentifier: defaultActionIdentifier,
                dismissActionIdentifier: dismissActionIdentifier
            )
        )
    }

    /// Resolves a route URL from a decoded payload and response context.
    public static func resolveRouteURL(
        payload: MHNotificationPayload?,
        response: MHNotificationResponseContext
    ) -> URL? {
        guard let payload else {
            return nil
        }

        return MHNotificationRouteResolver.resolveRouteURL(
            payload: payload,
            response: response
        )
    }

    /// Resolves a route URL, applies app-specific fallback policy, and delivers it.
    @preconcurrency
    public static func deliverRouteURL(
        payload: MHNotificationPayload?,
        response: MHNotificationResponseContext,
        deliver: @MainActor @Sendable (URL?) async -> Void,
        clearPendingURLWhenNoRoute: Bool = false,
        fallbackRouteURL: @Sendable (MHNotificationPayload?, MHNotificationResponseContext) -> URL? = { _, _ in nil }
    ) async -> MHNotificationRouteDeliveryOutcome {
        let outcome = routeDeliveryOutcome(
            payload: payload,
            response: response,
            fallbackRouteURL: fallbackRouteURL
        )

        if clearPendingURLWhenNoRoute || outcome.routeURL != nil {
            await deliver(outcome.routeURL)
        }

        return outcome
    }

    /// Resolves a route URL, applies app-specific fallback policy, and delivers it.
    @preconcurrency
    public static func deliverRouteURL(
        userInfo: sending [AnyHashable: Any],
        actionIdentifier: String,
        codec: MHNotificationPayloadCodec = .init(),
        deliver: @MainActor @Sendable (URL?) async -> Void,
        clearPendingURLWhenNoRoute: Bool = false,
        fallbackRouteURL: @Sendable (MHNotificationPayload?, MHNotificationResponseContext) -> URL? = { _, _ in nil },
        defaultActionIdentifier: String = "com.apple.UNNotificationDefaultActionIdentifier",
        dismissActionIdentifier: String = "com.apple.UNNotificationDismissActionIdentifier"
    ) async -> MHNotificationRouteDeliveryOutcome {
        let payload = codec.decode(userInfo)
        let response = MHNotificationResponseContext(
            actionIdentifier: actionIdentifier,
            defaultActionIdentifier: defaultActionIdentifier,
            dismissActionIdentifier: dismissActionIdentifier
        )

        return await deliverRouteURL(
            payload: payload,
            response: response,
            deliver: deliver,
            clearPendingURLWhenNoRoute: clearPendingURLWhenNoRoute,
            fallbackRouteURL: fallbackRouteURL
        )
    }

    private static func routeDeliveryOutcome(
        payload: MHNotificationPayload?,
        response: MHNotificationResponseContext,
        fallbackRouteURL: @Sendable (MHNotificationPayload?, MHNotificationResponseContext) -> URL?
    ) -> MHNotificationRouteDeliveryOutcome {
        if let routeURL = resolveRouteURL(
            payload: payload,
            response: response
        ) {
            return .init(
                routeURL: routeURL,
                source: .payload
            )
        }

        if let routeURL = fallbackRouteURL(
            payload,
            response
        ) {
            return .init(
                routeURL: routeURL,
                source: .fallback
            )
        }

        return .init(
            routeURL: nil,
            source: .noRoute
        )
    }
}
#endif
