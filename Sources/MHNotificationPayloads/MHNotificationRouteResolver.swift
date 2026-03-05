import Foundation

/// Resolves a route URL from payload targets and response context.
public enum MHNotificationRouteResolver {
    /// Resolves route URL in this order: dismiss, action-specific, default, fallback.
    public static func resolveRouteURL(
        payload: MHNotificationPayload,
        response: MHNotificationResponseContext
    ) -> URL? {
        if response.actionIdentifier == response.dismissActionIdentifier {
            return nil
        }

        if let actionRouteURL = payload.routes.actionRouteURLs[response.actionIdentifier] {
            return actionRouteURL
        }

        if let defaultRouteURL = payload.routes.defaultRouteURL {
            return defaultRouteURL
        }

        if let fallbackRouteURL = payload.routes.fallbackRouteURL {
            return fallbackRouteURL
        }

        return nil
    }
}
