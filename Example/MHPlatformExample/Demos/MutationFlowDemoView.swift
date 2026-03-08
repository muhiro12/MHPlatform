import MHPlatform
import SwiftUI

struct MutationFlowDemoView: View {
    nonisolated private enum Constants {
        static let firstAttempt = 1
        static let retryMaximumAttempts = 2
        static let eventLogDisplayOffset = 1
    }

    nonisolated private struct MutationScenario: Sendable {
        let failFirstAttempt: Bool
        let failSideEffect: Bool
        let cancelBeforeStepTwo: Bool

        let followUpSignals: [FollowUpSignal] = [
            .reloadWidgets,
            .syncNotifications,
            .requestReview
        ]
    }

    nonisolated struct SaveDraftResult: Sendable {
        let message: String
        let followUpSignals: [FollowUpSignal]
    }

    nonisolated enum FollowUpSignal: String, Sendable {
        case reloadWidgets
        case syncNotifications
        case requestReview

        var stepName: String {
            rawValue
        }
    }

    private actor MutationAttemptState {
        private var attempts = 0

        func nextAttempt() -> Int {
            attempts += 1
            return attempts
        }
    }

    nonisolated private enum MutationDemoError: Error {
        case operationFailed
        case sideEffectFailed
    }

    @State private var failFirstAttempt = true
    @State private var failSideEffect = false
    @State private var cancelBeforeStepTwo = false
    @State private var isRunning = false
    @State private var outcomeSummary = "Run the sample mutation flow."
    @State private var eventLog = [String]()

    var body: some View {
        NavigationStack {
            List {
                scenarioSection
                outcomeSection
                eventLogSection
            }
            .navigationTitle("MHMutationFlow")
        }
    }

    private var scenarioSection: some View {
        Section("Scenario") {
            Toggle("Fail first attempt", isOn: $failFirstAttempt)
                .disabled(isRunning)
            Toggle("Fail side effect", isOn: $failSideEffect)
                .disabled(isRunning)
            Toggle("Cancel before step 2", isOn: $cancelBeforeStepTwo)
                .disabled(isRunning)

            Button(isRunning ? "Running..." : "Run Flow") {
                runFlow()
            }
            .disabled(isRunning)
        }
    }

    private var outcomeSection: some View {
        Section("Outcome") {
            Text(outcomeSummary)
                .textSelection(.enabled)
        }
    }

    private var eventLogSection: some View {
        Section("Event Log") {
            if eventLog.isEmpty {
                Text("No events recorded yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(
                    Array(eventLog.enumerated()),
                    id: \.offset
                ) { index, event in
                    Text("\(index + Constants.eventLogDisplayOffset). \(event)")
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                }
            }
        }
    }

    nonisolated private static func makeMutation(
        attempts: MutationAttemptState,
        scenario: MutationScenario
    ) -> MHMutation<SaveDraftResult> {
        .init(
            name: "saveDraft"
        ) {
            let attempt = await attempts.nextAttempt()
            if scenario.failFirstAttempt,
               attempt == Constants.firstAttempt {
                throw MutationDemoError.operationFailed
            }

            return .init(
                message: "Saved sample draft",
                followUpSignals: scenario.followUpSignals
            )
        }
    }

    nonisolated private static func makeAdapter(
        scenario: MutationScenario,
        cancellationHandle: MHCancellationHandle
    ) -> MHMutationAdapter<SaveDraftResult> {
        let workflowAdapter = MHMutationAdapter<SaveDraftResult> { result in
            result.followUpSignals.compactMap { signal in
                switch signal {
                case .reloadWidgets, .syncNotifications:
                    return makeFollowUpStep(
                        for: signal,
                        scenario: scenario,
                        cancellationHandle: cancellationHandle
                    )
                case .requestReview:
                    return nil
                }
            }
        }
        let reviewAdapter = MHMutationAdapter<SaveDraftResult> { result in
            guard result.followUpSignals.contains(.requestReview) else {
                return []
            }

            return [
                makeFollowUpStep(
                    for: .requestReview,
                    scenario: scenario,
                    cancellationHandle: cancellationHandle
                )
            ]
        }

        return workflowAdapter.appending(reviewAdapter)
    }

    nonisolated private static func makeFollowUpStep(
        for signal: FollowUpSignal,
        scenario: MutationScenario,
        cancellationHandle: MHCancellationHandle
    ) -> MHMutationStep {
        switch signal {
        case .reloadWidgets:
            return .init(name: signal.stepName) {
                if scenario.cancelBeforeStepTwo {
                    cancellationHandle.cancel()
                }
            }
        case .syncNotifications:
            return .init(name: signal.stepName) {
                if scenario.failSideEffect {
                    throw MutationDemoError.sideEffectFailed
                }
            }
        case .requestReview:
            return .init(name: signal.stepName) {
                // Intentionally empty.
            }
        }
    }

    private func runFlow() {
        let scenario = MutationScenario(
            failFirstAttempt: failFirstAttempt,
            failSideEffect: failSideEffect,
            cancelBeforeStepTwo: cancelBeforeStepTwo
        )

        isRunning = true
        outcomeSummary = "Running sample save flow..."
        eventLog = []

        Task {
            await runFlowTask(scenario: scenario)
        }
    }

    private func runFlowTask(scenario: MutationScenario) async {
        let cancellationHandle = MHCancellationHandle()
        let attempts = MutationAttemptState()
        let mutation = Self.makeMutation(
            attempts: attempts,
            scenario: scenario
        )
        let adapter = Self.makeAdapter(
            scenario: scenario,
            cancellationHandle: cancellationHandle
        )
        let eventLogRecorder = Self.EventLogRecorder()
        let outcome = await MHMutationRunner.run(
            mutation: mutation,
            adapter: adapter,
            retryPolicy: .init(
                maximumAttempts: Constants.retryMaximumAttempts,
                backoff: .immediate
            ),
            cancellationHandle: cancellationHandle
        ) { event in
            eventLogRecorder.record(
                Self.eventTitle(event)
            )
        }
        let events = eventLogRecorder.all()

        await MainActor.run {
            eventLog = events
            outcomeSummary = Self.summarize(outcome)
            isRunning = false
        }
    }
}
