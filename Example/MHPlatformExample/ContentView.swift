import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            tabs
        }
        // swiftlint:disable:next no_magic_numbers
        .frame(minWidth: 900, minHeight: 640)
    }

    @ViewBuilder private var tabs: some View {
        appRuntimeTab
        deepLinkRoutePipelineTab
        notificationPipelineTab
        mutationReviewPipelineTab
        deepLinkingTab
        preferencesTab
        notificationPayloadsTab
        notificationPlansTab
        mutationFlowTab
        routeExecutionTab
        reviewPolicyTab
        persistenceMaintenanceTab
    }

    private var appRuntimeTab: some View {
        AppRuntimeDemoView()
            .tabItem {
                Label("Runtime", systemImage: "bolt.horizontal.circle")
            }
    }

    private var deepLinkRoutePipelineTab: some View {
        DeepLinkRoutePipelineDemoView()
            .tabItem {
                Label("DeepLink Route", systemImage: "arrow.triangle.merge")
            }
    }

    private var notificationPipelineTab: some View {
        NotificationPipelineDemoView()
            .tabItem {
                Label("Plans Payloads", systemImage: "bell.and.waves.left.and.right")
            }
    }

    private var mutationReviewPipelineTab: some View {
        MutationReviewPipelineDemoView()
            .tabItem {
                Label("Mutation Review", systemImage: "star.leadinghalf.filled")
            }
    }

    private var deepLinkingTab: some View {
        DeepLinkingDemoView()
            .tabItem {
                Label("Deep Links", systemImage: "link")
            }
    }

    private var notificationPlansTab: some View {
        NotificationPlansDemoView()
            .tabItem {
                Label("Plans", systemImage: "calendar.badge.clock")
            }
    }

    private var mutationFlowTab: some View {
        MutationFlowDemoView()
            .tabItem {
                Label("Mutation Flow", systemImage: "arrow.triangle.2.circlepath")
            }
    }

    private var routeExecutionTab: some View {
        RouteExecutionDemoView()
            .tabItem {
                Label("Route Execution", systemImage: "map")
            }
    }

    private var preferencesTab: some View {
        PreferencesDemoView()
            .tabItem {
                Label("Preferences", systemImage: "slider.horizontal.3")
            }
    }

    private var reviewPolicyTab: some View {
        ReviewPolicyDemoView()
            .tabItem {
                Label("Review", systemImage: "star.bubble")
            }
    }

    private var notificationPayloadsTab: some View {
        NotificationPayloadsDemoView()
            .tabItem {
                Label("Payloads", systemImage: "bell.badge")
            }
    }

    private var persistenceMaintenanceTab: some View {
        PersistenceMaintenanceDemoView()
            .tabItem {
                Label("Persistence", systemImage: "externaldrive")
            }
    }
}

#Preview {
    ContentView()
}
