import Foundation
import SwiftUI

@MainActor
private struct MHAppRoutePipelineModifier<Route: Sendable>: ViewModifier {
    let pipeline: MHAppRoutePipeline<Route>

    func body(content: Content) -> some View {
        content
            .onOpenURL { incomingURL in
                Task {
                    await pipeline.ingest(incomingURL)
                }
            }
            .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { userActivity in
                guard let webpageURL = userActivity.webpageURL else {
                    return
                }

                Task {
                    await pipeline.ingest(webpageURL)
                }
            }
            .onChange(of: pipeline.inbox.pendingURL) {
                Task {
                    await pipeline.synchronizePendingRoutesIfPossible()
                }
            }
    }
}

public extension View {
    /// Applies package-owned URL ingestion and pending-route synchronization.
    ///
    /// Prefer `mhAppRuntimeBootstrap(_:)` for standard app roots that already
    /// own `MHAppRuntimeBootstrap`. Use this lower-level modifier when route
    /// ingestion is integrated separately from runtime bootstrap.
    @MainActor
    func mhAppRoutePipeline<Route: Sendable>(
        _ pipeline: MHAppRoutePipeline<Route>
    ) -> some View {
        modifier(
            MHAppRoutePipelineModifier(
                pipeline: pipeline
            )
        )
    }
}
