actor MHRouteExecutionRouteRecorder {
    private var resolvedRoutes = [Int]()
    private var appliedOutcomes = [Int]()

    func recordResolvedRoute(_ route: Int) {
        resolvedRoutes.append(route)
    }

    func recordAppliedOutcome(_ outcome: Int) {
        appliedOutcomes.append(outcome)
    }

    func snapshot() -> (resolved: [Int], applied: [Int]) {
        (
            resolved: resolvedRoutes,
            applied: appliedOutcomes
        )
    }
}
