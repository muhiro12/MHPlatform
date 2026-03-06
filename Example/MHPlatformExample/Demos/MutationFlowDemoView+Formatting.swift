import MHPlatform

extension MutationFlowDemoView {
    func collectEventLog(
        from events: AsyncStream<MHMutationEvent<SaveDraftResult>>
    ) async -> [String] {
        var values = [String]()

        for await event in events {
            values.append(eventTitle(event))
        }

        return values
    }

    func eventTitle(_ event: MHMutationEvent<SaveDraftResult>) -> String {
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

    func progressTitle(_ progress: MHMutationProgress) -> String {
        switch progress {
        case let .retryScheduled(nextAttempt, delay):
            return "progress.retryScheduled(nextAttempt=\(nextAttempt), delay=\(delay))"
        case let .stepStarted(name, completedSteps, totalSteps):
            return "progress.stepStarted(\(name), \(completedSteps)/\(totalSteps))"
        case let .stepSucceeded(name, completedSteps, totalSteps):
            return "progress.stepSucceeded(\(name), \(completedSteps)/\(totalSteps))"
        }
    }

    func summarize(_ outcome: MHMutationOutcome<SaveDraftResult>) -> String {
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
