import Foundation
import MHLogging
import MHMutationFlow

/// Bridges `MHMutationWorkflow` events into `MHLogger`.
public struct MHMutationWorkflowLogger: Sendable {
    public let logger: MHLogger
    public let logsProgressEvents: Bool

    public init(
        logger: MHLogger,
        logsProgressEvents: Bool = false
    ) {
        self.logger = logger
        self.logsProgressEvents = logsProgressEvents
    }

    /// Returns an event sink suitable for `MHMutationWorkflow.runThrowing`.
    public func onEvent<Value: Sendable>(
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) -> MHMutationWorkflow.EventSink<Value> {
        { event in
            log(
                event,
                file: file,
                function: function,
                line: line
            )
        }
    }
}

private extension MHMutationWorkflowLogger {
    struct LogSourceContext {
        let file: String
        let function: String
        let line: Int
    }

    func log<Value: Sendable>(
        _ event: MHMutationEvent<Value>,
        file: String,
        function: String,
        line: Int
    ) {
        let sourceContext = LogSourceContext(
            file: file,
            function: function,
            line: line
        )

        switch event {
        case let .started(mutation, attempt):
            logStarted(
                mutation: mutation,
                attempt: attempt,
                sourceContext: sourceContext
            )
        case let .progress(progress):
            logProgress(
                progress,
                sourceContext: sourceContext
            )
        case let .succeeded(_, attempts, completedSteps):
            logSucceeded(
                attempts: attempts,
                completedSteps: completedSteps,
                sourceContext: sourceContext
            )
        case let .failed(errorDescription, attempts, completedSteps, isRecoverable):
            logFailed(
                errorDescription: errorDescription,
                attempts: attempts,
                completedSteps: completedSteps,
                isRecoverable: isRecoverable,
                sourceContext: sourceContext
            )
        case let .cancelled(attempts, completedSteps):
            logCancelled(
                attempts: attempts,
                completedSteps: completedSteps,
                sourceContext: sourceContext
            )
        }
    }

    func logStarted(
        mutation: String,
        attempt: Int,
        sourceContext: LogSourceContext
    ) {
        logger.info(
            "Mutation started",
            metadata: MHLogMetadata.merge(
                ["mutation": mutation],
                MHLogMetadata.count("attempt", attempt)
            ),
            file: sourceContext.file,
            function: sourceContext.function,
            line: sourceContext.line
        )
    }

    func logSucceeded(
        attempts: Int,
        completedSteps: [String],
        sourceContext: LogSourceContext
    ) {
        logger.info(
            "Mutation completed",
            metadata: completionMetadata(
                attempts: attempts,
                completedSteps: completedSteps
            ),
            file: sourceContext.file,
            function: sourceContext.function,
            line: sourceContext.line
        )
    }

    func logFailed(
        errorDescription: String,
        attempts: Int,
        completedSteps: [String],
        isRecoverable: Bool,
        sourceContext: LogSourceContext
    ) {
        logger.error(
            "Mutation failed",
            metadata: MHLogMetadata.merge(
                completionMetadata(
                    attempts: attempts,
                    completedSteps: completedSteps
                ),
                ["error": errorDescription],
                MHLogMetadata.bool("isRecoverable", isRecoverable)
            ),
            file: sourceContext.file,
            function: sourceContext.function,
            line: sourceContext.line
        )
    }

    func logCancelled(
        attempts: Int,
        completedSteps: [String],
        sourceContext: LogSourceContext
    ) {
        logger.notice(
            "Mutation cancelled",
            metadata: completionMetadata(
                attempts: attempts,
                completedSteps: completedSteps
            ),
            file: sourceContext.file,
            function: sourceContext.function,
            line: sourceContext.line
        )
    }

    func logProgress(
        _ progress: MHMutationProgress,
        sourceContext: LogSourceContext
    ) {
        guard logsProgressEvents else {
            return
        }

        logger.debug(
            "Mutation progress",
            metadata: progressMetadata(progress),
            file: sourceContext.file,
            function: sourceContext.function,
            line: sourceContext.line
        )
    }

    func completionMetadata(
        attempts: Int,
        completedSteps: [String]
    ) -> [String: String] {
        MHLogMetadata.merge(
            MHLogMetadata.count("attempts", attempts),
            MHLogMetadata.count("completedStepCount", completedSteps.count),
            ["completedSteps": completedSteps.joined(separator: ",")]
        )
    }

    func progressMetadata(
        _ progress: MHMutationProgress
    ) -> [String: String] {
        switch progress {
        case let .retryScheduled(nextAttempt, delay):
            return MHLogMetadata.merge(
                ["progress": "retryScheduled"],
                MHLogMetadata.count("nextAttempt", nextAttempt),
                ["delay": String(describing: delay)]
            )
        case let .stepStarted(name, completedSteps, totalSteps):
            return stepProgressMetadata(
                progress: "stepStarted",
                name: name,
                completedSteps: completedSteps,
                totalSteps: totalSteps
            )
        case let .stepSucceeded(name, completedSteps, totalSteps):
            return stepProgressMetadata(
                progress: "stepSucceeded",
                name: name,
                completedSteps: completedSteps,
                totalSteps: totalSteps
            )
        }
    }

    func stepProgressMetadata(
        progress: String,
        name: String,
        completedSteps: Int,
        totalSteps: Int
    ) -> [String: String] {
        MHLogMetadata.merge(
            [
                "progress": progress,
                "step": name
            ],
            MHLogMetadata.count("completedSteps", completedSteps),
            MHLogMetadata.count("totalSteps", totalSteps)
        )
    }
}
