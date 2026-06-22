import Foundation
import MHDeepLinking
import MHNotificationPayloads
import MHNotificationPlans
import MHPreferences
import MHRouteExecution

enum SurfaceAdapterConsumer {
    private enum Constants {
        static let customScheme = "surface-adapter-consumer"
        static let host = "example.com"
        static let universalLinkPrefix = "surface"
        static let routeHomePath = "home"
        static let routeItemPath = "item"
        static let routeHomePathComponentCount = 1
        static let routeItemPathComponentCount = 2
        static let itemIdentifier = "surface-item"
        static let routeStoreKey = "surface-adapter-consumer.pending-route-url"
        static let minimumAmount: Decimal = 1
        static let candidateAmount: Decimal = 5
        static let daysBeforeDueDate = 1
        static let dueDateOffsetDays = 3
        static let deliveryHour = 9
        static let deliveryMinute = 0
        static let reminderIdentifierPrefix = "surface-adapter-consumer:"
    }

    enum Route: Equatable, Sendable, MHDeepLinkRoute {
        case home
        case item(String)

        var deepLinkDescriptor: MHDeepLinkDescriptor {
            switch self {
            case .home:
                .init(pathComponents: [Constants.routeHomePath])
            case .item(let identifier):
                .init(
                    pathComponents: [
                        Constants.routeItemPath,
                        identifier
                    ]
                )
            }
        }

        init?(deepLinkDescriptor: MHDeepLinkDescriptor) {
            if deepLinkDescriptor.pathComponents.count == Constants.routeHomePathComponentCount,
               deepLinkDescriptor.pathComponents[0] == Constants.routeHomePath {
                self = .home
                return
            }

            guard deepLinkDescriptor.pathComponents.count == Constants.routeItemPathComponentCount,
                  deepLinkDescriptor.pathComponents[0] == Constants.routeItemPath else {
                return nil
            }

            self = .item(deepLinkDescriptor.pathComponents[1])
        }
    }

    static func makeCodec() -> MHDeepLinkCodec<Route> {
        .init(
            configuration: .init(
                customScheme: Constants.customScheme,
                preferredUniversalLinkHost: Constants.host,
                allowedUniversalLinkHosts: [Constants.host],
                universalLinkPathPrefix: Constants.universalLinkPrefix,
                preferredTransport: .customScheme
            )
        )
    }

    static func makeRouteStore(
        userDefaults: UserDefaults
    ) -> MHDeepLinkStore {
        .init(
            userDefaults: userDefaults,
            key: Constants.routeStoreKey
        )
    }

    @discardableResult
    static func storeIntentRoute(
        in store: MHDeepLinkStore
    ) -> URL? {
        store.ingest(
            .item(Constants.itemIdentifier),
            using: makeCodec()
        )
    }

    static func makeNotificationPayload() -> MHNotificationPayload? {
        let codec = makeCodec()
        guard let defaultRouteURL = codec.preferredURL(
            for: .item(Constants.itemIdentifier)
        ),
        let fallbackRouteURL = codec.preferredURL(for: .home) else {
            return nil
        }

        return .init(
            routes: .init(
                defaultRouteURL: defaultRouteURL,
                fallbackRouteURL: fallbackRouteURL
            )
        )
    }

    static func resolveDefaultNotificationRoute() -> Route? {
        guard let payload = makeNotificationPayload() else {
            return nil
        }

        guard let routeURL = MHNotificationRouteResolver.resolveRouteURL(
            payload: payload,
            response: .init(actionIdentifier: "default")
        ) else {
            return nil
        }

        return makeCodec().parse(routeURL)
    }

    static func makeReminderPlans(
        now: Date,
        calendar: Calendar
    ) -> [MHReminderPlan] {
        guard let deliveryTime = MHNotificationTime(
            hour: Constants.deliveryHour,
            minute: Constants.deliveryMinute
        ),
        let dueDate = calendar.date(
            byAdding: .day,
            value: Constants.dueDateOffsetDays,
            to: now
        ),
        let payload = makeNotificationPayload(),
        let primaryRouteURL = payload.routes.defaultRouteURL,
        let secondaryRouteURL = payload.routes.fallbackRouteURL else {
            return []
        }

        return MHReminderPlanner.build(
            candidates: [
                .init(
                    stableIdentifier: Constants.itemIdentifier,
                    title: "Surface item",
                    amount: Constants.candidateAmount,
                    dueDate: dueDate,
                    primaryRouteURL: primaryRouteURL,
                    secondaryRouteURL: secondaryRouteURL
                )
            ],
            policy: .init(
                isEnabled: true,
                minimumAmount: Constants.minimumAmount,
                daysBeforeDueDate: Constants.daysBeforeDueDate,
                deliveryTime: deliveryTime,
                identifierPrefix: Constants.reminderIdentifierPrefix
            ),
            now: now,
            calendar: calendar
        )
    }

    static func executeRoute(_ route: Route) async throws -> Route {
        try await MHRouteExecutor<Route, Route>.identity.execute(route)
    }
}
