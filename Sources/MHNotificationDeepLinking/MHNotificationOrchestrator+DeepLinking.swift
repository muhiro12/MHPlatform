#if canImport(UserNotifications)
import Foundation
import MHDeepLinking
import MHNotificationPayloads
import MHUserNotifications

public extension MHNotificationOrchestrator {
    /// Resolves a route URL, applies app-specific fallback policy, and stores it
    /// in a pending deep-link destination.
    static func deliverRouteURL<Destination: MHDeepLinkURLDestination>(
        payload: MHNotificationPayload?,
        response: MHNotificationResponseContext,
        destination: Destination,
        clearPendingURLWhenNoRoute: Bool = false,
        fallbackRouteURL: @Sendable (MHNotificationPayload?, MHNotificationResponseContext) -> URL? = { _, _ in nil }
    ) async -> MHNotificationRouteDeliveryOutcome {
        let outcome = routeDeliveryOutcome(
            payload: payload,
            response: response,
            fallbackRouteURL: fallbackRouteURL
        )

        return await deliverRouteURL(
            outcome,
            destination: destination,
            clearPendingURLWhenNoRoute: clearPendingURLWhenNoRoute
        )
    }

    /// Resolves a route URL, applies app-specific fallback policy, and stores it
    /// in a pending deep-link destination.
    static func deliverRouteURL<Destination: MHDeepLinkURLDestination>(
        userInfo: sending [AnyHashable: Any],
        actionIdentifier: String,
        destination: Destination,
        codec: MHNotificationPayloadCodec = .init(),
        clearPendingURLWhenNoRoute: Bool = false,
        fallbackRouteURL: @Sendable (MHNotificationPayload?, MHNotificationResponseContext) -> URL? = { _, _ in nil },
        defaultActionIdentifier: String = "com.apple.UNNotificationDefaultActionIdentifier",
        dismissActionIdentifier: String = "com.apple.UNNotificationDismissActionIdentifier"
    ) async -> MHNotificationRouteDeliveryOutcome {
        let outcome = routeDeliveryOutcome(
            userInfo: userInfo,
            actionIdentifier: actionIdentifier,
            codec: codec,
            fallbackRouteURL: fallbackRouteURL,
            defaultActionIdentifier: defaultActionIdentifier,
            dismissActionIdentifier: dismissActionIdentifier
        )

        return await deliverRouteURL(
            outcome,
            destination: destination,
            clearPendingURLWhenNoRoute: clearPendingURLWhenNoRoute
        )
    }

    /// Delivers a previously resolved route delivery outcome into a pending
    /// deep-link destination.
    static func deliverRouteURL<Destination: MHDeepLinkURLDestination>(
        _ outcome: MHNotificationRouteDeliveryOutcome,
        destination: Destination,
        clearPendingURLWhenNoRoute: Bool = false
    ) async -> MHNotificationRouteDeliveryOutcome {
        if clearPendingURLWhenNoRoute || outcome.routeURL != nil {
            await destination.setPendingURL(outcome.routeURL)
        }

        return outcome
    }
}
#endif
