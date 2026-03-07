import MHPlatform
import SwiftUI

struct MutationReviewPipelineDemoView: View {
    private enum Constants {
        static let retryMaximumAttempts = 2
        static let reviewLotteryMaxExclusive = 10
        static let forcedReviewLotteryHit = 0
    }

    enum Scenario: String, CaseIterable, Identifiable {
        case success
        case failure

        var id: String {
            rawValue
        }
    }

    @State private var scenario: Scenario = .success
    @State private var isRunning = false
    @State private var mutationSummary = "Run a mutation scenario."
    @State private var reviewSummary = "Review policy has not been triggered yet."

    var body: some View {
        NavigationStack {
            List {
                scenarioSection
                mutationOutcomeSection
                reviewOutcomeSection
            }
            .navigationTitle("Mutation + Review")
        }
    }

    private var scenarioSection: some View {
        Section("Scenario") {
            Picker("Mutation", selection: $scenario) {
                ForEach(Scenario.allCases) { scenario in
                    Text(scenario.rawValue).tag(scenario)
                }
            }
            .pickerStyle(.segmented)

            Button(isRunning ? "Running..." : "Run Pipeline") {
                runPipeline()
            }
            .disabled(isRunning)
        }
    }

    private var mutationOutcomeSection: some View {
        Section("Mutation Outcome") {
            Text(mutationSummary)
                .font(.caption.monospaced())
                .textSelection(.enabled)
        }
    }

    private var reviewOutcomeSection: some View {
        Section("Review Policy Outcome") {
            Text(reviewSummary)
                .font(.caption.monospaced())
                .textSelection(.enabled)
        }
    }

    private func runPipeline() {
        isRunning = true
        mutationSummary = "Running mutation..."
        reviewSummary = "Waiting for mutation outcome..."

        Task {
            let outcome = await runMutationScenario(scenario)
            let review = await triggerReviewIfNeeded(from: outcome)

            await MainActor.run {
                mutationSummary = describeMutationOutcome(outcome)
                reviewSummary = review
                isRunning = false
            }
        }
    }

    private func runMutationScenario(_ scenario: Scenario) async -> MHMutationOutcome<String> {
        let mutation = MHMutation<String>(
            name: "saveDraft"
        ) {
            if scenario == .failure {
                throw PipelineError.mutationFailed
            }
            return "saved"
        }

        return await MHMutationRunner.run(
            mutation: mutation,
            retryPolicy: .init(
                maximumAttempts: Constants.retryMaximumAttempts,
                backoff: .immediate
            ),
            afterSuccess: [
                .init(name: "syncNotifications") {
                    // Intentionally empty.
                }
            ]
        )
    }

    @MainActor
    private func triggerReviewIfNeeded(
        from mutationOutcome: MHMutationOutcome<String>
    ) async -> String {
        guard case .succeeded = mutationOutcome else {
            return "Skipped: mutation did not succeed."
        }

        let policy = MHReviewPolicy(
            lotteryMaxExclusive: Constants.reviewLotteryMaxExclusive,
            requestDelay: .zero
        )

        let outcome = await MHReviewRequester.requestIfNeeded(
            policy: policy,
            randomValueProvider: { _ in
                Constants.forcedReviewLotteryHit
            },
            sleep: { _ in
                // Intentionally empty.
            }
        )

        return "Triggered after success: \(outcome)"
    }

    private func describeMutationOutcome(_ outcome: MHMutationOutcome<String>) -> String {
        switch outcome {
        case let .succeeded(value, attempts, completedSteps):
            return [
                "succeeded(value=\(value)",
                "attempts=\(attempts)",
                "completed=\(completedSteps))"
            ].joined(separator: ", ")
        case let .failed(failure, attempts, completedSteps, isRecoverable):
            return [
                "failed(failure=\(failure)",
                "attempts=\(attempts)",
                "completed=\(completedSteps)",
                "recoverable=\(isRecoverable))"
            ].joined(separator: ", ")
        case let .cancelled(attempts, completedSteps):
            return [
                "cancelled(attempts=\(attempts)",
                "completed=\(completedSteps))"
            ].joined(separator: ", ")
        }
    }
}

private extension MutationReviewPipelineDemoView {
    enum PipelineError: Error {
        case mutationFailed
    }
}
