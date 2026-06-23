import MHMutationFlow
import MHReviewFlow
import MHReviewPolicy

enum OptionalShellConsumer {
    private enum Constants {
        static let lotteryMaxExclusive = 10
        static let reviewName = "requestReview"
        static let workflowName = "optional-shell-consumer"
        static let adapterValue = 1
    }

    @MainActor
    static func makeReviewFlow() -> MHReviewFlow {
        .init(
            policy: .init(
                lotteryMaxExclusive: Constants.lotteryMaxExclusive,
                requestDelay: .zero
            )
        )
    }

    @MainActor
    static func makeAdapter() -> MHMutationAdapter<Int> {
        .fixed([
            makeReviewFlow().step(name: Constants.reviewName)
        ])
    }

    @MainActor
    static func makeMutationStep() -> MHMutationStep {
        makeReviewFlow().step(name: Constants.reviewName)
    }

    @MainActor
    static func exerciseRuntimeTaskAPI() {
        _ = makeReviewFlow().task(name: Constants.reviewName)
    }

    @MainActor
    static func runWorkflow() async throws -> Int {
        try await MHMutationWorkflow.runThrowing(
            name: Constants.workflowName,
            operation: {
                Constants.adapterValue
            },
            adapter: makeAdapter(),
            adapterValue: Constants.adapterValue,
            options: .init(
                configuration: .init(
                    retryPolicy: .default
                )
            )
        )
    }
}
