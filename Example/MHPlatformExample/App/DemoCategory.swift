import Foundation

enum DemoCategory: CaseIterable, Identifiable {
    case runtime
    case routing
    case notifications
    case workflows

    var id: Self {
        self
    }

    var title: String {
        switch self {
        case .runtime:
            return "Runtime"
        case .routing:
            return "Routing"
        case .notifications:
            return "Notifications"
        case .workflows:
            return "Workflows"
        }
    }

    var systemImage: String {
        switch self {
        case .runtime:
            return "bolt.horizontal.circle"
        case .routing:
            return "arrow.triangle.merge"
        case .notifications:
            return "bell.badge"
        case .workflows:
            return "arrow.triangle.2.circlepath"
        }
    }

    var demos: [Demo] {
        switch self {
        case .runtime:
            return [
                .runtime,
                .preferences,
                .review
            ]
        case .routing:
            return [
                .deepLinkRoute,
                .deepLinks,
                .routeExecution
            ]
        case .notifications:
            return [
                .notificationPipeline,
                .notificationPayloads,
                .notificationPlans
            ]
        case .workflows:
            return [
                .mutationReview,
                .mutationFlow,
                .logging,
                .persistence
            ]
        }
    }
}
