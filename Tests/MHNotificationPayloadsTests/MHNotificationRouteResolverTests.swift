import Foundation
import MHNotificationPayloads
import Testing

struct MHNotificationRouteResolverTests {
    @Test
    func dismiss_action_returns_nil() {
        let payload = makePayload(
            defaultRouteURL: "mhkit://item?id=rent",
            fallbackRouteURL: "mhkit://month?year=2026&month=1",
            actionRouteURLs: [
                "view-month": "mhkit://month?year=2026&month=1"
            ]
        )
        let response = MHNotificationResponseContext(
            actionIdentifier: "com.apple.UNNotificationDismissActionIdentifier"
        )

        let resolved = MHNotificationRouteResolver.resolveRouteURL(
            payload: payload,
            response: response
        )

        #expect(resolved == nil)
    }

    @Test
    func action_specific_route_wins_over_default() {
        let payload = makePayload(
            defaultRouteURL: "mhkit://item?id=rent",
            fallbackRouteURL: "mhkit://month?year=2026&month=1",
            actionRouteURLs: [
                "view-month": "mhkit://month?year=2026&month=1"
            ]
        )
        let response = MHNotificationResponseContext(
            actionIdentifier: "view-month"
        )

        let resolved = MHNotificationRouteResolver.resolveRouteURL(
            payload: payload,
            response: response
        )

        #expect(resolved == url("mhkit://month?year=2026&month=1"))
    }

    @Test
    func unknown_action_falls_back_to_default() {
        let payload = makePayload(
            defaultRouteURL: "mhkit://item?id=rent",
            fallbackRouteURL: "mhkit://month?year=2026&month=1"
        )
        let response = MHNotificationResponseContext(
            actionIdentifier: "unknown-action"
        )

        let resolved = MHNotificationRouteResolver.resolveRouteURL(
            payload: payload,
            response: response
        )

        #expect(resolved == url("mhkit://item?id=rent"))
    }

    @Test
    func missing_default_falls_back_to_fallback() {
        let payload = makePayload(
            fallbackRouteURL: "mhkit://month?year=2026&month=1"
        )
        let response = MHNotificationResponseContext(
            actionIdentifier: "unknown-action"
        )

        let resolved = MHNotificationRouteResolver.resolveRouteURL(
            payload: payload,
            response: response
        )

        #expect(resolved == url("mhkit://month?year=2026&month=1"))
    }

    @Test
    func no_routes_returns_nil() {
        let payload = MHNotificationPayload(
            routes: .init(defaultRouteURL: nil)
        )
        let response = MHNotificationResponseContext(
            actionIdentifier: "unknown-action"
        )

        let resolved = MHNotificationRouteResolver.resolveRouteURL(
            payload: payload,
            response: response
        )

        #expect(resolved == nil)
    }

    private func makePayload(
        defaultRouteURL: String? = nil,
        fallbackRouteURL: String? = nil,
        actionRouteURLs: [String: String] = [:]
    ) -> MHNotificationPayload {
        MHNotificationPayload(
            routes: .init(
                defaultRouteURL: defaultRouteURL.map(url(_:)),
                fallbackRouteURL: fallbackRouteURL.map(url(_:)),
                actionRouteURLs: Dictionary(
                    uniqueKeysWithValues: actionRouteURLs.map { key, value in
                        (key, url(value))
                    }
                )
            )
        )
    }

    private func url(_ value: String) -> URL {
        guard let parsedURL = URL(string: value) else {
            preconditionFailure("Invalid URL value: \(value)")
        }
        return parsedURL
    }
}
