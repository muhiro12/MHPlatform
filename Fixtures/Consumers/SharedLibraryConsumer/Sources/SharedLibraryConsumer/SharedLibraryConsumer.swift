import Foundation
import MHPlatformCore

enum SharedLibraryConsumer {
    private enum Constants {
        static let customScheme = "shared-library-consumer"
        static let host = "example.com"
        static let universalLinkPrefix = "shared"
        static let routeItemPath = "item"
        static let routePathComponentCount = 2
        static let minimumAmount: Decimal = 1
        static let daysBeforeDueDate = 1
        static let deliveryHour = 9
        static let deliveryMinute = 0
        static let identifierPrefix = "shared-library-consumer"
        static let loggerCategory = "shared-library-consumer"
    }

    enum Route: Equatable, Sendable, MHDeepLinkRoute {
        case item(String)

        var deepLinkDescriptor: MHDeepLinkDescriptor {
            switch self {
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
            guard deepLinkDescriptor.pathComponents.count == Constants.routePathComponentCount,
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

    static func makeLogger() -> MHLogger {
        MHLoggerFactory.osLogDefault.logger(
            category: Constants.loggerCategory,
            source: #fileID
        )
    }

    static func makePreferenceStore() -> MHPreferenceStore {
        .init()
    }

    static func makeReminderPolicy() -> MHReminderPolicy {
        guard let deliveryTime = MHNotificationTime(
            hour: Constants.deliveryHour,
            minute: Constants.deliveryMinute
        ) else {
            preconditionFailure("Invalid fixture delivery time.")
        }

        return .init(
            isEnabled: true,
            minimumAmount: Constants.minimumAmount,
            daysBeforeDueDate: Constants.daysBeforeDueDate,
            deliveryTime: deliveryTime,
            identifierPrefix: Constants.identifierPrefix
        )
    }
}
