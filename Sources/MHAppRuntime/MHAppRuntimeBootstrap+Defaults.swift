import MHAppRuntimeCore

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

    // swiftlint:disable function_default_parameter_at_end
    /// Creates a bootstrap with the default runtime adapters and route pipeline.
    @preconcurrency
    init<Route: Sendable>(
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
}
