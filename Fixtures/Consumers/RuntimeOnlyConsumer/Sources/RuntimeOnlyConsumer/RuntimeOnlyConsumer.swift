import MHAppRuntime
import MHPreferences
import SwiftUI

enum RuntimeOnlyConsumer {
    private enum Constants {
        static let preferencesDefaults = MHUserDefaultsSelection.suite(
            "fixture.runtime-only"
        )
        static let startupTaskName = "runtimeOnlyStartup"
    }

    @MainActor
    static func makeBootstrap() -> MHAppRuntimeBootstrap {
        .init(
            runtimeOnlyConfiguration: .init(
                preferencesDefaults: Constants.preferencesDefaults,
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
