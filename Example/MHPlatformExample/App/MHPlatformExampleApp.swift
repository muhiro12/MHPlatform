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
            showsLicenses: true,
            adsConsent: MHPlatformExampleAdMobConfiguration.adsConsent
        )
    )

    var body: some Scene {
        WindowGroup {
            ContentView()
                .mhAppRuntimeBootstrap(bootstrap)
        }
    }
}
