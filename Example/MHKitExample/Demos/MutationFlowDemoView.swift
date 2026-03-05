import MHMutationFlow
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
    }

    private actor MutationAttemptState {
        private var attempts = 0

        func nextAttempt() -> Int {
            attempts += 1
            return attempts
        }
    }

    nonisolated private final class MutationEventRecorder: @unchecked Sendable {
        private let lock = NSLock()
        private var values = [String]()

        private static func title(for event: MHMutationEvent) -> String {
            switch event {
            case .attemptStarted(let attempt):
                return "attemptStarted(\(attempt))"
            case let .attemptFailed(attempt, message):
                return "attemptFailed(\(attempt)): \(message)"
            case .attemptSucceeded(let attempt):
                return "attemptSucceeded(\(attempt))"
            case .stepStarted(let name):
                return "stepStarted(\(name))"
            case .stepSucceeded(let name):
                return "stepSucceeded(\(name))"
            case let .stepFailed(name, message):
                return "stepFailed(\(name)): \(message)"
            case .cancelled:
                return "cancelled"
            }
        }

        func record(_ event: MHMutationEvent) {
            lock.lock()
            values.append(Self.title(for: event))
            lock.unlock()
        }

        func events() -> [String] {
            lock.lock()
            let snapshot = values
            lock.unlock()
            return snapshot
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
        let recorder = MutationEventRecorder()
        let cancellationHandle = MHCancellationHandle()
        let attempts = MutationAttemptState()
        let eventSink: @Sendable (MHMutationEvent) -> Void = { event in
            recorder.record(event)
        }

        let outcome = await MHMutationRunner.run(
            operation: {
                let attempt = await attempts.nextAttempt()
                if scenario.failFirstAttempt, attempt == Constants.firstAttempt {
                    throw MutationDemoError.operationFailed
                }
                return "Saved sample draft"
            },
            retryPolicy: MHMutationRetryPolicy(
                maximumAttempts: Constants.retryMaximumAttempts,
                backoff: .immediate
            ),
            cancellationHandle: cancellationHandle,
            afterSuccess: [
                MHMutationStep(name: "reloadWidgets") {
                    if scenario.cancelBeforeStepTwo {
                        cancellationHandle.cancel()
                    }
                },
                MHMutationStep(name: "syncNotifications") {
                    if scenario.failSideEffect {
                        throw MutationDemoError.sideEffectFailed
                    }
                },
                MHMutationStep(name: "requestReview") {
                    // no-op
                }
            ],
            onEvent: eventSink
        )

        await MainActor.run {
            eventLog = recorder.events()
            outcomeSummary = summarize(outcome)
            isRunning = false
        }
    }

    private func summarize(_ outcome: MHMutationOutcome<String>) -> String {
        switch outcome {
        case let .succeeded(value, attempts, completedSteps):
            return """
            Succeeded after \(attempts) attempt(s): \(value) | \
            steps \(completedSteps.joined(separator: ", "))
            """
        case let .failed(error, attempts, completedSteps):
            return """
            Failed after \(attempts) attempt(s): \(String(describing: error)) | \
            completed \(completedSteps.joined(separator: ", "))
            """
        case let .cancelled(attempts, completedSteps):
            return """
            Cancelled after \(attempts) attempt(s) | \
            completed \(completedSteps.joined(separator: ", "))
            """
        }
    }
}
