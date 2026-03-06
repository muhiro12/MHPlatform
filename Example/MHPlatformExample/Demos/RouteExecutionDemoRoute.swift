enum RouteExecutionDemoRoute: String, CaseIterable, Identifiable, Sendable {
    case home
    case search
    case settings
    case broken

    var id: String {
        rawValue
    }

    var buttonTitle: String {
        switch self {
        case .home:
            return "Handle Home Route"
        case .search:
            return "Handle Search Route"
        case .settings:
            return "Handle Settings Route"
        case .broken:
            return "Handle Broken Route"
        }
    }
}
