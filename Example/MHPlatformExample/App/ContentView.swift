import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            coreTabs
            notificationTabs
            diagnosticsTabs
        }
        // swiftlint:disable:next no_magic_numbers
        .frame(minWidth: 900, minHeight: 640)
    }

    @TabContentBuilder<Never> private var coreTabs: some TabContent<Never> {
        Tab("Runtime", systemImage: "bolt.horizontal.circle") {
            AppRuntimeDemoView()
        }
        Tab("DeepLink Route", systemImage: "arrow.triangle.merge") {
            DeepLinkRoutePipelineDemoView()
        }
        Tab("Mutation Review", systemImage: "star.leadinghalf.filled") {
            MutationReviewPipelineDemoView()
        }
        Tab("Deep Links", systemImage: "link") {
            DeepLinkingDemoView()
        }
        Tab("Preferences", systemImage: "slider.horizontal.3") {
            PreferencesDemoView()
        }
    }

    @TabContentBuilder<Never> private var notificationTabs: some TabContent<Never> {
        Tab("Plans Payloads", systemImage: "bell.and.waves.left.and.right") {
            NotificationPipelineDemoView()
        }
        Tab("Payloads", systemImage: "bell.badge") {
            NotificationPayloadsDemoView()
        }
        Tab("Plans", systemImage: "calendar.badge.clock") {
            NotificationPlansDemoView()
        }
        Tab("Mutation Flow", systemImage: "arrow.triangle.2.circlepath") {
            MutationFlowDemoView()
        }
    }

    @TabContentBuilder<Never> private var diagnosticsTabs: some TabContent<Never> {
        Tab("Route Execution", systemImage: "map") {
            RouteExecutionDemoView()
        }
        Tab("Logging", systemImage: "list.bullet.clipboard") {
            LoggingDemoView()
        }
        Tab("Review", systemImage: "star.bubble") {
            ReviewPolicyDemoView()
        }
        Tab("Persistence", systemImage: "externaldrive") {
            PersistenceMaintenanceDemoView()
        }
    }
}

#Preview {
    ContentView()
}
