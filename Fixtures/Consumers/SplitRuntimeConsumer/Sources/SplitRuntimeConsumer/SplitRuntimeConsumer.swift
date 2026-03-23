import MHAppRuntime
import MHAppRuntimeAds
import MHAppRuntimeDefaults
import MHAppRuntimeLicenses
import SwiftUI

enum SplitRuntimeConsumer {
    private enum Constants {
        static let subscriptionProductID = "premium.monthly"
        static let preferencesSuiteName = "fixture.split-runtime"
        static let startupTaskName = "splitRuntimeStartup"
    }

    @MainActor
    static func makeBootstrap() -> MHAppRuntimeBootstrap {
        let configuration = MHAppConfiguration(
            subscriptionProductIDs: [Constants.subscriptionProductID],
            preferencesSuiteName: Constants.preferencesSuiteName,
            showsLicenses: false
        )
        let defaultsBundle = MHAppRuntimeDefaultsBundle(
            configuration: configuration
        )
        let adsBundle = MHAppRuntimeAdsBundle(
            configuration: configuration
        )
        let licensesBundle = MHAppRuntimeLicensesBundle(
            configuration: configuration
        )
        let runtime = MHAppRuntime(
            configuration: configuration,
            preferenceStore: defaultsBundle.preferenceStore,
            startStore: defaultsBundle.startStore,
            subscriptionSectionFactory: defaultsBundle.subscriptionSectionFactory,
            startAds: adsBundle.startAds,
            nativeAdFactory: adsBundle.nativeAdFactory,
            licensesFactory: licensesBundle.licensesFactory
        )

        return .init(
            runtime: runtime,
            lifecyclePlan: .init(
                startupTasks: [
                    .init(name: Constants.startupTaskName) {
                        await Task.yield()
                    }
                ]
            )
        )
    }

    @MainActor
    static func rootView<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .mhAppRuntimeEnvironment(makeBootstrap())
    }
}
