import MHAppRuntime
import SwiftUI

struct RuntimeRootView: View {
    @Environment(\.scenePhase)
    private var scenePhase
    @Environment(MHAppRuntime.self)
    private var runtime

    var body: some View {
        ContentView()
            .task {
                runtime.startIfNeeded()
            }
            .onChange(of: scenePhase) {
                guard scenePhase == .active else {
                    return
                }
                runtime.startIfNeeded()
            }
    }
}

#Preview {
    RuntimeRootView()
        .environment(
            MHAppRuntime(
                configuration: .init(
                    subscriptionProductIDs: ["com.example.mhplatform.premium.monthly"],
                    nativeAdUnitID: "ca-app-pub-3940256099942544/3986624511",
                    preferencesSuiteName: "MHPlatformExample.Runtime",
                    showsLicenses: true
                )
            )
        )
}
