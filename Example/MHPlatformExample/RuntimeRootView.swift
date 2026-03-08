import MHPlatform
import SwiftUI

struct RuntimeRootView: View {
    @Environment(MHAppRuntime.self)
    private var runtime

    var body: some View {
        ContentView()
            .mhAppRuntimeLifecycle(runtime: runtime)
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
