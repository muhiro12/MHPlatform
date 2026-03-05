import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            DeepLinkingDemoView()
                .tabItem {
                    Label("Deep Links", systemImage: "link")
                }

            NotificationPlansDemoView()
                .tabItem {
                    Label("Plans", systemImage: "calendar.badge.clock")
                }

            MutationFlowDemoView()
                .tabItem {
                    Label("Mutation Flow", systemImage: "arrow.triangle.2.circlepath")
                }

            PreferencesDemoView()
                .tabItem {
                    Label("Preferences", systemImage: "slider.horizontal.3")
                }

            NotificationPayloadsDemoView()
                .tabItem {
                    Label("Payloads", systemImage: "bell.badge")
                }
        }
        // swiftlint:disable:next no_magic_numbers
        .frame(minWidth: 900, minHeight: 640)
    }
}

#Preview {
    ContentView()
}
