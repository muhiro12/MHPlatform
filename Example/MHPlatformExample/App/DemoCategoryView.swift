import SwiftUI

struct DemoCategoryView: View {
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
        switch demo.category {
        case .runtime:
            runtimeDestination(for: demo)
        case .routing:
            routingDestination(for: demo)
        case .notifications:
            notificationDestination(for: demo)
        case .workflows:
            workflowDestination(for: demo)
        }
    }

    @ViewBuilder
    private func runtimeDestination(for demo: Demo) -> some View {
        switch demo {
        case .runtime:
            AppRuntimeDemoView()
        case .preferences:
            PreferencesDemoView()
        case .review:
            ReviewPolicyDemoView()
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private func routingDestination(for demo: Demo) -> some View {
        switch demo {
        case .deepLinkRoute:
            DeepLinkRoutePipelineDemoView()
        case .deepLinks:
            DeepLinkingDemoView()
        case .routeExecution:
            RouteExecutionDemoView()
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private func notificationDestination(for demo: Demo) -> some View {
        switch demo {
        case .notificationPipeline:
            NotificationPipelineDemoView()
        case .notificationPayloads:
            NotificationPayloadsDemoView()
        case .notificationPlans:
            NotificationPlansDemoView()
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private func workflowDestination(for demo: Demo) -> some View {
        switch demo {
        case .mutationReview:
            MutationReviewPipelineDemoView()
        case .mutationFlow:
            MutationFlowDemoView()
        case .logging:
            LoggingDemoView()
        case .persistence:
            PersistenceMaintenanceDemoView()
        default:
            EmptyView()
        }
    }
}
