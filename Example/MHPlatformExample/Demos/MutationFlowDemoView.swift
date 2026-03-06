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

    nonisolated private struct SaveDraftResult: Sendable {
        let message: String
        let followUpSignals: [FollowUpSignal]
    }

    nonisolated private enum FollowUpSignal: String, Sendable {
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

    private static func makeMutation(
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

    private static func makeAdapter(
        scenario: MutationScenario,
        cancellationHandle: MHCancellationHandle
    ) -> MHMutationAdapter<SaveDraftResult> {
        .init { result in
            result.followUpSignals.map { signal in
                makeFollowUpStep(
                    for: signal,
                    scenario: scenario,
                    cancellationHandle: cancellationHandle
                )
            }
        }
    }

    private static func makeFollowUpStep(
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

        let runHandle = MHMutationRunner.start(
            mutation: mutation,
            adapter: adapter,
            retryPolicy: .init(
                maximumAttempts: Constants.retryMaximumAttempts,
                backoff: .immediate
            ),
            cancellationHandle: cancellationHandle
        )

        async let eventLogTask = collectEventLog(from: runHandle.events)
        let outcome = await runHandle.outcome.value
        let events = await eventLogTask

        await MainActor.run {
            eventLog = events
            outcomeSummary = summarize(outcome)
            isRunning = false
        }
    }

    private func collectEventLog(
        from events: AsyncStream<MHMutationEvent<SaveDraftResult>>
    ) async -> [String] {
        var values = [String]()

        for await event in events {
            values.append(eventTitle(event))
        }

        return values
    }

    private func eventTitle(_ event: MHMutationEvent<SaveDraftResult>) -> String {
        switch event {
        case let .started(mutation, attempt):
            return "started(\(mutation), attempt=\(attempt))"
        case .progress(let progress):
            return progressTitle(progress)
        case let .succeeded(value, attempts, completedSteps):
            return [
                "succeeded(value=\(value.message)",
                "attempts=\(attempts)",
                "completed=\(completedSteps))"
            ].joined(separator: ", ")
        case let .failed(errorDescription, attempts, completedSteps, isRecoverable):
            return [
                "failed(attempts=\(attempts)",
                "recoverable=\(isRecoverable)",
                "completed=\(completedSteps)",
                "error=\(errorDescription))"
            ].joined(separator: ", ")
        case let .cancelled(attempts, completedSteps):
            return "cancelled(attempts=\(attempts), completed=\(completedSteps))"
        }
    }

    private func progressTitle(_ progress: MHMutationProgress) -> String {
        switch progress {
        case let .retryScheduled(nextAttempt, delay):
            return "progress.retryScheduled(nextAttempt=\(nextAttempt), delay=\(delay))"
        case let .stepStarted(name, completedSteps, totalSteps):
            return "progress.stepStarted(\(name), \(completedSteps)/\(totalSteps))"
        case let .stepSucceeded(name, completedSteps, totalSteps):
            return "progress.stepSucceeded(\(name), \(completedSteps)/\(totalSteps))"
        }
    }

    private func summarize(_ outcome: MHMutationOutcome<SaveDraftResult>) -> String {
        switch outcome {
        case let .succeeded(value, attempts, completedSteps):
            return [
                "Succeeded after \(attempts) attempt(s): \(value.message)",
                "steps \(completedSteps.joined(separator: ", "))"
            ].joined(separator: " | ")
        case let .failed(failure, attempts, completedSteps, isRecoverable):
            return [
                "Failed after \(attempts) attempt(s): \(failure)",
                "recoverable=\(isRecoverable)",
                "completed \(completedSteps.joined(separator: ", "))"
            ].joined(separator: " | ")
        case let .cancelled(attempts, completedSteps):
            return [
                "Cancelled after \(attempts) attempt(s)",
                "completed \(completedSteps.joined(separator: ", "))"
            ].joined(separator: " | ")
        }
    }
}
