import Foundation
import MHDeepLinking

/// Package-owned runtime assembly shell for app root integration.
@MainActor
@preconcurrency
public struct MHAppRuntimeBootstrap {
    /// Runtime owned by the bootstrap.
    public let runtime: MHAppRuntime

    /// Ordered lifecycle plan applied by the bootstrap.
    public let lifecyclePlan: MHAppRuntimeLifecyclePlan

    /// Shared observable inbox exposed when route integration is configured.
    public var routeInbox: MHObservableDeepLinkInbox? {
        routeHooks?.inbox
    }

    private let routeHooks: RouteHooks?

    /// Creates a bootstrap around an existing runtime.
    public init(
        runtime: MHAppRuntime,
        lifecyclePlan: MHAppRuntimeLifecyclePlan = .empty
    ) {
        self.runtime = runtime
        self.lifecyclePlan = lifecyclePlan
        self.routeHooks = nil
    }

    /// Creates a bootstrap with a runtime configuration.
    public init(
        configuration: MHAppConfiguration,
        lifecyclePlan: MHAppRuntimeLifecyclePlan = .empty
    ) {
        self.init(
            runtime: .init(configuration: configuration),
            lifecyclePlan: lifecyclePlan
        )
    }

    // swiftlint:disable function_default_parameter_at_end
    /// Creates a bootstrap around an existing runtime and route pipeline.
    @preconcurrency
    public init<Route: Sendable>(
        runtime: MHAppRuntime,
        lifecyclePlan: MHAppRuntimeLifecyclePlan = .empty,
        routePipeline: MHAppRoutePipeline<Route>
    ) {
        self.runtime = runtime
        self.lifecyclePlan = lifecyclePlan
        self.routeHooks = .init(routePipeline: routePipeline)
    }

    /// Creates a bootstrap with a runtime configuration and route pipeline.
    @preconcurrency
    public init<Route: Sendable>(
        configuration: MHAppConfiguration,
        lifecyclePlan: MHAppRuntimeLifecyclePlan = .empty,
        routePipeline: MHAppRoutePipeline<Route>
    ) {
        self.init(
            runtime: .init(configuration: configuration),
            lifecyclePlan: lifecyclePlan,
            routePipeline: routePipeline
        )
    }
    // swiftlint:enable function_default_parameter_at_end

    /// Builds a lifecycle coordinator for manual integration sites.
    public func makeLifecycle() -> MHAppRuntimeLifecycle {
        .init(
            runtime: runtime,
            plan: lifecyclePlan
        )
    }
}

extension MHAppRuntimeBootstrap {
    func ingest(_ url: URL) async {
        guard let routeHooks else {
            return
        }

        await routeHooks.ingest(url)
    }

    func synchronizePendingRoutesIfPossible() async {
        guard let routeHooks else {
            return
        }

        await routeHooks.synchronizePendingRoutesIfPossible()
    }
}

private extension MHAppRuntimeBootstrap {
    struct RouteHooks {
        let inbox: MHObservableDeepLinkInbox
        let ingest: @MainActor @Sendable (URL) async -> Void
        let synchronizePendingRoutesIfPossible: @MainActor @Sendable () async -> Void

        init<Route: Sendable>(
            routePipeline: MHAppRoutePipeline<Route>
        ) {
            self.inbox = routePipeline.inbox
            self.ingest = { incomingURL in
                await routePipeline.ingest(incomingURL)
            }
            self.synchronizePendingRoutesIfPossible = {
                _ = await routePipeline.synchronizePendingRoutesIfPossible()
            }
        }
    }
}
