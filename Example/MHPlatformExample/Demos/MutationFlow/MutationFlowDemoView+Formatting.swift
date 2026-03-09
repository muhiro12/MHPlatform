import Foundation
import MHPlatform

extension MutationFlowDemoView {
    final class EventLogRecorder: @unchecked Sendable {
        private let lock = NSLock()
        private var values = [String]()

        func record(_ value: String) {
            lock.lock()
            values.append(value)
            lock.unlock()
        }

        func all() -> [String] {
            lock.lock()
            defer {
                lock.unlock()
            }

            return values
        }
    }

    static func eventTitle(_ event: MHMutationEvent<SaveDraftResult>) -> String {
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

    static func progressTitle(_ progress: MHMutationProgress) -> String {
        switch progress {
        case let .retryScheduled(nextAttempt, delay):
            return "progress.retryScheduled(nextAttempt=\(nextAttempt), delay=\(delay))"
        case let .stepStarted(name, completedSteps, totalSteps):
            return "progress.stepStarted(\(name), \(completedSteps)/\(totalSteps))"
        case let .stepSucceeded(name, completedSteps, totalSteps):
            return "progress.stepSucceeded(\(name), \(completedSteps)/\(totalSteps))"
        }
    }

    static func summarize(_ outcome: MHMutationOutcome<SaveDraftResult>) -> String {
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
