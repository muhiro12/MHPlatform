import SwiftUI

@MainActor
private struct MHAppRuntimeBootstrapModifier: ViewModifier {
    let bootstrap: MHAppRuntimeBootstrap

    @ViewBuilder
    func body(content: Content) -> some View {
        if let routeInbox = bootstrap.routeInbox {
            content
                .environment(bootstrap.runtime)
                .mhAppRuntimeLifecycle(
                    runtime: bootstrap.runtime,
                    plan: bootstrap.lifecyclePlan
                )
                .onOpenURL { incomingURL in
                    Task {
                        await bootstrap.ingest(incomingURL)
                    }
                }
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { userActivity in
                    guard let webpageURL = userActivity.webpageURL else {
                        return
                    }

                    Task {
                        await bootstrap.ingest(webpageURL)
                    }
                }
                .onChange(of: routeInbox.pendingURL) {
                    Task {
                        await bootstrap.synchronizePendingRoutesIfPossible()
                    }
                }
        } else {
            content
                .environment(bootstrap.runtime)
                .mhAppRuntimeLifecycle(
                    runtime: bootstrap.runtime,
                    plan: bootstrap.lifecyclePlan
                )
        }
    }
}

public extension View {
    /// Applies runtime environment injection, lifecycle handling, and optional
    /// route plumbing from a bootstrap shell.
    @MainActor
    func mhAppRuntimeBootstrap(
        _ bootstrap: MHAppRuntimeBootstrap
    ) -> some View {
        modifier(
            MHAppRuntimeBootstrapModifier(
                bootstrap: bootstrap
            )
        )
    }
}
