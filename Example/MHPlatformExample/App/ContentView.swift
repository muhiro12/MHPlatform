import SwiftUI

struct ContentView: View {
    var body: some View {
        content
    }

    @ViewBuilder
    private var content: some View {
        #if os(macOS)
        tabs
            // swiftlint:disable:next no_magic_numbers
            .frame(minWidth: 900, minHeight: 640)
        #else
        tabs
        #endif
    }

    private var tabs: some View {
        TabView {
            Tab("Runtime", systemImage: "bolt.horizontal.circle") {
                DemoCategoryView(
                    title: "Runtime",
                    demos: [
                        .runtime,
                        .preferences,
                        .review
                    ]
                )
            }
            Tab("Routing", systemImage: "arrow.triangle.merge") {
                DemoCategoryView(
                    title: "Routing",
                    demos: [
                        .deepLinkRoute,
                        .deepLinks,
                        .routeExecution
                    ]
                )
            }
            Tab("Notifications", systemImage: "bell.badge") {
                DemoCategoryView(
                    title: "Notifications",
                    demos: [
                        .notificationPipeline,
                        .notificationPayloads,
                        .notificationPlans
                    ]
                )
            }
            Tab("Workflows", systemImage: "arrow.triangle.2.circlepath") {
                DemoCategoryView(
                    title: "Workflows",
                    demos: [
                        .mutationReview,
                        .mutationFlow,
                        .logging,
                        .persistence
                    ]
                )
            }
        }
    }
}

private struct DemoCategoryView: View {
    let title: String
    let demos: [Demo]

    var body: some View {
        NavigationStack {
            List(demos) { demo in
                NavigationLink {
                    destination(for: demo)
                } label: {
                    Label(demo.title, systemImage: demo.systemImage)
                }
            }
            .navigationTitle(title)
        }
    }

    @ViewBuilder
    private func destination(for demo: Demo) -> some View {
        switch demo {
        case .runtime:
            AppRuntimeDemoView()
        case .deepLinkRoute:
            DeepLinkRoutePipelineDemoView()
        case .mutationReview:
            MutationReviewPipelineDemoView()
        case .deepLinks:
            DeepLinkingDemoView()
        case .preferences:
            PreferencesDemoView()
        case .notificationPipeline:
            NotificationPipelineDemoView()
        case .notificationPayloads:
            NotificationPayloadsDemoView()
        case .notificationPlans:
            NotificationPlansDemoView()
        case .mutationFlow:
            MutationFlowDemoView()
        case .routeExecution:
            RouteExecutionDemoView()
        case .logging:
            LoggingDemoView()
        case .review:
            ReviewPolicyDemoView()
        case .persistence:
            PersistenceMaintenanceDemoView()
        }
    }
}

private enum Demo: String, CaseIterable, Identifiable {
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

#Preview {
    ContentView()
}
