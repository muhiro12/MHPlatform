import MHAppRuntime

public extension MHAppRuntimeBootstrap {
    /// Creates a bootstrap with the default runtime adapters.
    init(
        configuration: MHAppConfiguration,
        lifecyclePlan: MHAppRuntimeLifecyclePlan = .empty
    ) {
        self.init(
            runtime: .init(configuration: configuration),
            lifecyclePlan: lifecyclePlan
        )
    }

    /// Creates a bootstrap with the default runtime adapters and route pipeline.
    @preconcurrency
    init<Route: Sendable>(
        configuration: MHAppConfiguration,
        routePipeline: MHAppRoutePipeline<Route>,
        lifecyclePlan: MHAppRuntimeLifecyclePlan = .empty
    ) {
        self.init(
            runtime: .init(configuration: configuration),
            routePipeline: routePipeline,
            lifecyclePlan: lifecyclePlan
        )
    }
}
