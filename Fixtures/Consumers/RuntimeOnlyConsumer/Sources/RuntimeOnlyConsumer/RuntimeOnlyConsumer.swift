import MHAppRuntime
import SwiftUI

enum RuntimeOnlyConsumer {
    private enum Constants {
        static let startupTaskName = "runtimeOnlyStartup"
    }

    @MainActor
    static func makeBootstrap() -> MHAppRuntimeBootstrap {
        .init(
            runtimeOnlyConfiguration: .init(
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
