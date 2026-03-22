import MHAppRuntimeCore
import SwiftUI

enum RuntimeOnlyConsumer {
    private enum Constants {
        static let preferencesSuiteName = "fixture.runtime-only"
        static let startupTaskName = "runtimeOnlyStartup"
    }

    @MainActor
    static func makeBootstrap() -> MHAppRuntimeBootstrap {
        .init(
            runtimeOnlyConfiguration: .init(
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
    static func makeLifecycle() -> MHAppRuntimeLifecycle {
        makeBootstrap().makeLifecycle()
    }

    @MainActor
    static func rootView<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .mhAppRuntimeEnvironment(makeBootstrap())
    }
}
