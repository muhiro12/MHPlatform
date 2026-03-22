import MHAppRuntime
import SwiftUI

enum DefaultRuntimeConsumer {
    private enum Constants {
        static let subscriptionProductID = "premium.monthly"
        static let preferencesSuiteName = "fixture.default-runtime"
        static let startupTaskName = "defaultRuntimeStartup"
    }

    @MainActor
    static func makeBootstrap() -> MHAppRuntimeBootstrap {
        .init(
            configuration: .init(
                subscriptionProductIDs: [Constants.subscriptionProductID],
                preferencesSuiteName: Constants.preferencesSuiteName,
                showsLicenses: false
            ),
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
