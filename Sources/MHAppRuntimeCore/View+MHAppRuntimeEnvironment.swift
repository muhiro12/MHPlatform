import SwiftUI

public extension View {
    /// Applies only the runtime environment without lifecycle or route wiring.
    @MainActor
    func mhAppRuntimeEnvironment(
        _ runtime: MHAppRuntime
    ) -> some View {
        environment(runtime)
    }

    /// Applies only the runtime environment from a bootstrap shell.
    @MainActor
    func mhAppRuntimeEnvironment(
        _ bootstrap: MHAppRuntimeBootstrap
    ) -> some View {
        environment(bootstrap.runtime)
    }
}
