import MHRouteExecution
import SwiftUI

@MainActor
private struct MHRouteHandlerModifier<Route: Sendable>: ViewModifier {
    let routeInbox: MHObservableRouteInbox<Route>
    let apply: MHObservableRouteInbox<Route>.Handler

    func body(content: Content) -> some View {
        content
            .onAppear {
                routeInbox.registerHandler(apply)
                Task {
                    await routeInbox.resynchronizePendingRoutesIfPossible()
                }
            }
            .onDisappear {
                routeInbox.unregisterHandler()
            }
            .onChange(of: routeInbox.pendingRoute != nil) {
                guard routeInbox.pendingRoute != nil else {
                    return
                }

                Task {
                    await routeInbox.resynchronizePendingRoutesIfPossible()
                }
            }
    }
}

public extension View {
    /// Registers a route handler against an observable route inbox.
    ///
    /// Use this when the app wants package-owned latest-route buffering and
    /// replay while keeping route meaning and navigation mutations app-owned.
    /// This replaces manual register/unregister/resynchronize glue in root
    /// views.
    @MainActor
    func mhRouteHandler<Route: Sendable>(
        _ routeInbox: MHObservableRouteInbox<Route>,
        apply: @escaping MHObservableRouteInbox<Route>.Handler
    ) -> some View {
        modifier(
            MHRouteHandlerModifier(
                routeInbox: routeInbox,
                apply: apply
            )
        )
    }
}
