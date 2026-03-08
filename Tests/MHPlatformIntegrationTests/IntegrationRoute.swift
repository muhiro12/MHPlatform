import MHDeepLinking

enum IntegrationRoute: Equatable, Sendable, MHDeepLinkRoute {
    case item(Int)

    var identifier: Int {
        switch self {
        case .item(let identifier):
            return identifier
        }
    }

    var deepLinkDescriptor: MHDeepLinkDescriptor {
        switch self {
        case .item(let identifier):
            return .init(
                pathComponents: [
                    "item",
                    String(identifier)
                ]
            )
        }
    }

    init?(deepLinkDescriptor: MHDeepLinkDescriptor) {
        guard deepLinkDescriptor.pathComponents.count == TestConstants.routePathComponentCount,
              deepLinkDescriptor.pathComponents[0] == "item",
              let identifier = Int(deepLinkDescriptor.pathComponents[1]) else {
            return nil
        }

        self = .item(identifier)
    }
}
