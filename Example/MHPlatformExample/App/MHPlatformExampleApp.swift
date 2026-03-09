import MHPlatform
import SwiftUI

@main
struct MHPlatformExampleApp: App {
    @State private var bootstrap = MHAppRuntimeBootstrap(
        configuration: .init(
            subscriptionProductIDs: [
                "com.example.mhplatform.premium.monthly"
            ],
            nativeAdUnitID: "ca-app-pub-3940256099942544/3986624511",
            preferencesSuiteName: "MHPlatformExample.Runtime",
            showsLicenses: true
        )
    )

    var body: some Scene {
        WindowGroup {
            ContentView()
                .mhAppRuntimeBootstrap(bootstrap)
        }
    }
}
