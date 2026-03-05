import MHMutationFlow
import MHReviewPolicy
import SwiftUI

struct MutationReviewPipelineDemoView: View {
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

                Section("Mutation Outcome") {
                    Text(mutationSummary)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                }

                Section("Review Policy Outcome") {
                    Text(reviewSummary)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                }
            }
            .navigationTitle("Mutation + Review")
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
        )            {
                if scenario == .failure {
                    throw PipelineError.mutationFailed
                }
                return "saved"
            }

        return await MHMutationRunner.run(
            mutation: mutation,
            retryPolicy: .init(
                maximumAttempts: 2,
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
            lotteryMaxExclusive: 10,
            requestDelay: .zero
        )

        let outcome = await MHReviewRequester.requestIfNeeded(
            policy: policy,
            randomValueProvider: { _ in
                0
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
            return "succeeded(value=\(value), attempts=\(attempts), completed=\(completedSteps))"
        case let .failed(failure, attempts, completedSteps, isRecoverable):
            return "failed(failure=\(failure), attempts=\(attempts), completed=\(completedSteps), recoverable=\(isRecoverable))"
        case let .cancelled(attempts, completedSteps):
            return "cancelled(attempts=\(attempts), completed=\(completedSteps))"
        }
    }
}

private extension MutationReviewPipelineDemoView {
    enum PipelineError: Error {
        case mutationFailed
    }
}
