import MHPlatform
import SwiftUI

struct ReviewPolicyDemoView: View {
    nonisolated private enum Constants {
        static let minimumLotteryMaxExclusive = 1
        static let maximumLotteryMaxExclusive = 20
        static let minimumDelaySeconds = 0
        static let maximumDelaySeconds = 5
    }

    @State private var lotteryMaxExclusive = 10
    @State private var requestDelaySeconds = 2
    @State private var randomValue = 0
    @State private var policyDecision = "Not evaluated yet."
    @State private var requestOutcome = "Run requester to inspect behavior."
    @State private var isRunning = false

    var body: some View {
        NavigationStack {
            List {
                policyConfigurationSection
                lotterySection
                requesterSection
                resultsSection
            }
            .navigationTitle("MHReviewPolicy")
            .onChange(of: lotteryMaxExclusive) {
                randomValue = min(randomValue, randomValueRange.upperBound)
            }
        }
    }

    private var policyConfigurationSection: some View {
        Section("Policy") {
            Stepper(
                "lotteryMaxExclusive: \(lotteryMaxExclusive)",
                value: $lotteryMaxExclusive,
                in: Constants.minimumLotteryMaxExclusive...Constants.maximumLotteryMaxExclusive
            )

            Stepper(
                "requestDelaySeconds: \(requestDelaySeconds)",
                value: $requestDelaySeconds,
                in: Constants.minimumDelaySeconds...Constants.maximumDelaySeconds
            )
        }
    }

    private var lotterySection: some View {
        Section("Lottery Input") {
            Stepper(
                "randomValue: \(randomValue)",
                value: $randomValue,
                in: randomValueRange
            )

            Button("Evaluate Policy") {
                let shouldRequest = currentPolicy.shouldRequestReview(
                    randomValue: randomValue
                )
                policyDecision = shouldRequest
                    ? "Policy decision: request review"
                    : "Policy decision: skip review"
            }
        }
    }

    private var requesterSection: some View {
        Section("Requester") {
            Button(isRunning ? "Running..." : "Run Requester") {
                runRequester()
            }
            .disabled(isRunning)
        }
    }

    private var resultsSection: some View {
        Section("Results") {
            Text(policyDecision)
            Text(requestOutcome)
                .font(.caption.monospaced())
                .textSelection(.enabled)
        }
    }

    private var currentPolicy: MHReviewPolicy {
        .init(
            lotteryMaxExclusive: lotteryMaxExclusive,
            requestDelay: .seconds(requestDelaySeconds)
        )
    }

    private var randomValueRange: ClosedRange<Int> {
        0...max(0, lotteryMaxExclusive - 1)
    }

    private func runRequester() {
        let policy = currentPolicy
        let currentRandomValue = randomValue

        isRunning = true
        requestOutcome = "Running review flow..."

        Task {
            let randomValueProvider: MHReviewRequester.RandomValueProvider = { _ in
                currentRandomValue
            }
            let flow = MHReviewFlow(
                policy: policy,
                randomValueProvider: randomValueProvider
            )
            let outcome = await flow.requestIfNeeded()

            await MainActor.run {
                requestOutcome = "Review flow outcome: \(String(describing: outcome))"
                isRunning = false
            }
        }
    }
}
