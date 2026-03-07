import MHPlatform
import SwiftUI

struct MutationReviewPipelineDemoView: View {
    nonisolated private enum Constants {
        static let reviewLotteryMaxExclusive = 10
        static let forcedReviewLotteryHit = 0
    }

    nonisolated enum Scenario: String, CaseIterable, Identifiable {
        case success
        case failure

        var id: String {
            rawValue
        }
    }

    nonisolated private struct SaveDraftResult: Sendable {
        let message: String
        let shouldSynchronizeNotifications: Bool
        let shouldRequestReview: Bool
    }

    nonisolated private struct PipelineSummaries: Sendable {
        let mutation: String
        let review: String
    }

    nonisolated private struct PipelineSnapshot: Sendable {
        let didSynchronizeNotifications: Bool
        let reviewOutcome: MHReviewRequestOutcome?
    }

    private actor PipelineRecorder {
        private var didSynchronizeNotifications = false
        private var reviewOutcome: MHReviewRequestOutcome?

        func markNotificationsSynchronized() {
            didSynchronizeNotifications = true
        }

        func recordReviewOutcome(_ outcome: MHReviewRequestOutcome) {
            reviewOutcome = outcome
        }

        func snapshot() -> PipelineSnapshot {
            .init(
                didSynchronizeNotifications: didSynchronizeNotifications,
                reviewOutcome: reviewOutcome
            )
        }
    }

    @State private var scenario: Scenario = .success
    @State private var isRunning = false
    @State private var mutationSummary = "Run a mutation workflow scenario."
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

            Button(isRunning ? "Running..." : "Run Workflow") {
                runPipeline()
            }
            .disabled(isRunning)
        }
    }

    private var mutationOutcomeSection: some View {
        Section("Mutation Workflow") {
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
        let selectedScenario = scenario

        isRunning = true
        mutationSummary = "Running mutation workflow..."
        reviewSummary = "Waiting for mutation success..."

        Task {
            let recorder = PipelineRecorder()
            let summaries = await runPipelineTask(
                selectedScenario,
                recorder: recorder
            )

            await MainActor.run {
                mutationSummary = summaries.mutation
                reviewSummary = summaries.review
                isRunning = false
            }
        }
    }

    private func runPipelineTask(
        _ scenario: Scenario,
        recorder: PipelineRecorder
    ) async -> PipelineSummaries {
        do {
            let result = try await runMutationScenario(
                scenario,
                recorder: recorder
            )
            let snapshot = await recorder.snapshot()

            return .init(
                mutation: describeMutationSuccess(
                    result,
                    snapshot: snapshot
                ),
                review: describeReviewSummary(snapshot.reviewOutcome)
            )
        } catch is CancellationError {
            return .init(
                mutation: "cancelled",
                review: "Skipped: mutation workflow was cancelled."
            )
        } catch let error as MHMutationWorkflowError {
            return .init(
                mutation: "failed(error=\(error.description))",
                review: "Skipped: mutation workflow did not succeed."
            )
        } catch {
            return .init(
                mutation: "failed(error=\(error.localizedDescription))",
                review: "Skipped: mutation workflow did not succeed."
            )
        }
    }

    private func runMutationScenario(
        _ scenario: Scenario,
        recorder: PipelineRecorder
    ) async throws -> SaveDraftResult {
        let reviewPolicy = MHReviewPolicy(
            lotteryMaxExclusive: Constants.reviewLotteryMaxExclusive,
            requestDelay: .zero
        )

        let adapter = MHMutationAdapter<SaveDraftResult> { result in
            var steps = [MHMutationStep]()

            if result.shouldSynchronizeNotifications {
                steps.append(
                    .mainActor(name: "syncNotifications") {
                        await recorder.markNotificationsSynchronized()
                    }
                )
            }

            if result.shouldRequestReview {
                steps.append(
                    .mainActor(name: "requestReview") {
                        let outcome = await MHReviewRequester.requestIfNeeded(
                            policy: reviewPolicy,
                            randomValueProvider: { _ in
                                Constants.forcedReviewLotteryHit
                            },
                            sleep: { _ in
                                // Intentionally empty.
                            }
                        )
                        await recorder.recordReviewOutcome(outcome)
                    }
                )
            }

            return steps
        }

        return try await MHMutationWorkflow.runThrowing(
            name: "saveDraft",
            operation: {
                if scenario == .failure {
                    throw PipelineError.mutationFailed
                }

                return .init(
                    message: "saved",
                    shouldSynchronizeNotifications: true,
                    shouldRequestReview: true
                )
            },
            adapter: adapter,
            operationErrorDescription: Self.operationErrorDescription
        )
    }

    private func describeMutationSuccess(
        _ result: SaveDraftResult,
        snapshot: PipelineSnapshot
    ) -> String {
        [
            "succeeded(message=\(result.message)",
            "notificationsSynced=\(snapshot.didSynchronizeNotifications)",
            "reviewStep=\(snapshot.reviewOutcome != nil))"
        ].joined(separator: ", ")
    }

    private func describeReviewSummary(
        _ outcome: MHReviewRequestOutcome?
    ) -> String {
        guard let outcome else {
            return "Skipped: no review step ran."
        }

        return "Triggered after success: \(outcome)"
    }
}

private extension MutationReviewPipelineDemoView {
    nonisolated enum PipelineError: Error {
        case mutationFailed
    }

    nonisolated static func operationErrorDescription(
        _ error: any Error
    ) -> String {
        if let pipelineError = error as? PipelineError {
            switch pipelineError {
            case .mutationFailed:
                return "mutation failed"
            }
        }

        return error.localizedDescription
    }
}
