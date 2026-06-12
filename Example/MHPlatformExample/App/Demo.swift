import Foundation

enum Demo: String, CaseIterable, Identifiable {
    case runtime
    case deepLinkRoute
    case mutationReview
    case deepLinks
    case preferences
    case notificationPipeline
    case notificationPayloads
    case notificationPlans
    case mutationFlow
    case routeExecution
    case logging
    case review
    case persistence

    var id: Self {
        self
    }

    var category: DemoCategory {
        switch self {
        case .runtime,
             .preferences,
             .review:
            return .runtime
        case .deepLinkRoute,
             .deepLinks,
             .routeExecution:
            return .routing
        case .notificationPipeline,
             .notificationPayloads,
             .notificationPlans:
            return .notifications
        case .mutationReview,
             .mutationFlow,
             .logging,
             .persistence:
            return .workflows
        }
    }

    var title: String {
        switch self {
        case .runtime:
            return "Runtime"
        case .deepLinkRoute:
            return "DeepLink Route"
        case .mutationReview:
            return "Mutation Review"
        case .deepLinks:
            return "Deep Links"
        case .preferences:
            return "Preferences"
        case .notificationPipeline:
            return "Plans Payloads"
        case .notificationPayloads:
            return "Payloads"
        case .notificationPlans:
            return "Plans"
        case .mutationFlow:
            return "Mutation Flow"
        case .routeExecution:
            return "Route Execution"
        case .logging:
            return "Logging"
        case .review:
            return "Review"
        case .persistence:
            return "Persistence"
        }
    }

    var systemImage: String {
        switch self {
        case .runtime:
            return "bolt.horizontal.circle"
        case .deepLinkRoute:
            return "arrow.triangle.merge"
        case .mutationReview:
            return "star.leadinghalf.filled"
        case .deepLinks:
            return "link"
        case .preferences:
            return "slider.horizontal.3"
        case .notificationPipeline:
            return "bell.and.waves.left.and.right"
        case .notificationPayloads:
            return "bell.badge"
        case .notificationPlans:
            return "calendar.badge.clock"
        case .mutationFlow:
            return "arrow.triangle.2.circlepath"
        case .routeExecution:
            return "map"
        case .logging:
            return "list.bullet.clipboard"
        case .review:
            return "star.bubble"
        case .persistence:
            return "externaldrive"
        }
    }
}
