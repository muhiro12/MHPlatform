import MHPlatform
import SwiftUI

@main
struct MHPlatformExampleApp: App {
    @State private var bootstrap = MHAppRuntimeBootstrap(
        configuration: .init(
            subscriptionProductIDs: [
                "com.example.mhplatform.premium.monthly"
            ],
            nativeAdUnitID: MHPlatformExampleAdMobConfiguration.nativeAdUnitID,
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
