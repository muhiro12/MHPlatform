import SwiftUI

public extension View {
    /// Applies only the runtime environment without lifecycle or route wiring.
    ///
    /// Prefer this for previews, tests, and runtime-only screens that should
    /// not start lifecycle tasks.
    @MainActor
    func mhAppRuntimeEnvironment(
        _ runtime: MHAppRuntime
    ) -> some View {
        environment(runtime)
    }

    /// Applies only the runtime environment from a bootstrap shell.
    ///
    /// Prefer this when the app already owns a bootstrap but the current view
    /// should not start its lifecycle plan.
    @MainActor
    func mhAppRuntimeEnvironment(
        _ bootstrap: MHAppRuntimeBootstrap
    ) -> some View {
        environment(bootstrap.runtime)
    }
}
