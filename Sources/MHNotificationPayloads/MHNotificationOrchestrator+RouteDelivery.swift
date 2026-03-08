#if canImport(UserNotifications)
import Foundation
import MHDeepLinking

public extension MHNotificationOrchestrator {
    /// Resolves a route URL directly from userInfo and action identifier.
    static func resolveRouteURL(
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
    static func resolveRouteURL(
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
    static func deliverRouteURL(
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

    /// Resolves a route URL, applies app-specific fallback policy, and stores it
    /// in a pending deep-link destination.
    @preconcurrency
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

    /// Resolves a route URL, applies app-specific fallback policy, and delivers it.
    @preconcurrency
    static func deliverRouteURL(
        userInfo: sending [AnyHashable: Any],
        actionIdentifier: String,
        codec: MHNotificationPayloadCodec = .init(),
        deliver: @MainActor @Sendable (URL?) async -> Void,
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
            deliver: deliver,
            clearPendingURLWhenNoRoute: clearPendingURLWhenNoRoute
        )
    }

    /// Resolves a route URL, applies app-specific fallback policy, and stores it
    /// in a pending deep-link destination.
    @preconcurrency
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

    /// Resolves a route URL and returns the delivery outcome without performing delivery.
    @preconcurrency
    static func routeDeliveryOutcome(
        userInfo: [AnyHashable: Any],
        actionIdentifier: String,
        codec: MHNotificationPayloadCodec = .init(),
        fallbackRouteURL: @Sendable (MHNotificationPayload?, MHNotificationResponseContext) -> URL? = { _, _ in nil },
        defaultActionIdentifier: String = "com.apple.UNNotificationDefaultActionIdentifier",
        dismissActionIdentifier: String = "com.apple.UNNotificationDismissActionIdentifier"
    ) -> MHNotificationRouteDeliveryOutcome {
        let payload = codec.decode(userInfo)
        let response = MHNotificationResponseContext(
            actionIdentifier: actionIdentifier,
            defaultActionIdentifier: defaultActionIdentifier,
            dismissActionIdentifier: dismissActionIdentifier
        )

        return routeDeliveryOutcome(
            payload: payload,
            response: response,
            fallbackRouteURL: fallbackRouteURL
        )
    }

    /// Delivers a previously resolved route delivery outcome.
    @preconcurrency
    static func deliverRouteURL(
        _ outcome: MHNotificationRouteDeliveryOutcome,
        deliver: @MainActor @Sendable (URL?) async -> Void,
        clearPendingURLWhenNoRoute: Bool = false
    ) async -> MHNotificationRouteDeliveryOutcome {
        if clearPendingURLWhenNoRoute || outcome.routeURL != nil {
            await deliver(outcome.routeURL)
        }

        return outcome
    }

    /// Delivers a previously resolved route delivery outcome into a pending
    /// deep-link destination.
    @preconcurrency
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

private extension MHNotificationOrchestrator {
    static func routeDeliveryOutcome(
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
