import MHLogging
import MHMutationFlow
import MHMutationLogging
import Testing

struct MHMutationWorkflowLoggerTests {
    enum Constants {
        static let maximumEventWaitAttempts = 50
        static let eventWaitDelayNanoseconds: UInt64 = 1_000_000
    }

    @Test
    func onEvent_logs_terminal_mutation_events() async {
        let store = MHLogStore(
            policy: .init(
                minimumLevel: .debug,
                maximumInMemoryEvents: 20
            )
        )
        let logger = MHLogger(
            #fileID,
            store: store,
            subsystem: "tests.mutation-logging",
            category: "Mutation"
        )
        let workflowLogger = MHMutationWorkflowLogger(logger: logger)
        let onEvent: MHMutationWorkflow.EventSink<String> = workflowLogger.onEvent()

        onEvent(.started(mutation: "saveRecipe", attempt: 1))
        onEvent(.succeeded(value: "saved", attempts: 1, completedSteps: ["reloadWidgets"]))
        onEvent(
            .failed(
                errorDescription: "offline",
                attempts: 2,
                completedSteps: ["reloadWidgets"],
                isRecoverable: true
            )
        )
        onEvent(.cancelled(attempts: 3, completedSteps: []))

        let events = await waitForEvents(
            in: store,
            count: 4
        )

        #expect(events.map(\.level) == [.info, .info, .error, .notice])
        #expect(events.map(\.message) == [
            "Mutation started",
            "Mutation completed",
            "Mutation failed",
            "Mutation cancelled"
        ])
        #expect(events[0].metadata["mutation"] == "saveRecipe")
        #expect(events[0].metadata["attempt"] == "1")
        #expect(events[1].metadata["completedSteps"] == "reloadWidgets")
        #expect(events[2].metadata["error"] == "offline")
        #expect(events[2].metadata["isRecoverable"] == "true")
        #expect(events[3].metadata["attempts"] == "3")
    }

    @Test
    func onEvent_skips_progress_events_by_default() async {
        let store = MHLogStore(
            policy: .init(
                minimumLevel: .debug,
                maximumInMemoryEvents: 20
            )
        )
        let logger = MHLogger(
            #fileID,
            store: store,
            subsystem: "tests.mutation-logging",
            category: "Mutation"
        )
        let workflowLogger = MHMutationWorkflowLogger(logger: logger)
        let onEvent: MHMutationWorkflow.EventSink<String> = workflowLogger.onEvent()

        onEvent(
            .progress(
                .stepStarted(
                    name: "reloadWidgets",
                    completedSteps: 0,
                    totalSteps: 1
                )
            )
        )

        let events = await waitForEvents(
            in: store,
            count: 1,
            maximumAttempts: 5
        )

        #expect(events.isEmpty)
    }

    @Test
    func onEvent_logs_progress_events_when_enabled() async {
        let store = MHLogStore(
            policy: .init(
                minimumLevel: .debug,
                maximumInMemoryEvents: 20
            )
        )
        let logger = MHLogger(
            #fileID,
            store: store,
            subsystem: "tests.mutation-logging",
            category: "Mutation"
        )
        let workflowLogger = MHMutationWorkflowLogger(
            logger: logger,
            logsProgressEvents: true
        )
        let onEvent: MHMutationWorkflow.EventSink<String> = workflowLogger.onEvent()

        onEvent(
            .progress(
                .stepSucceeded(
                    name: "reloadWidgets",
                    completedSteps: 1,
                    totalSteps: 1
                )
            )
        )

        let events = await waitForEvents(
            in: store,
            count: 1
        )

        #expect(events.first?.level == .debug)
        #expect(events.first?.message == "Mutation progress")
        #expect(events.first?.metadata["progress"] == "stepSucceeded")
        #expect(events.first?.metadata["step"] == "reloadWidgets")
        #expect(events.first?.metadata["completedSteps"] == "1")
        #expect(events.first?.metadata["totalSteps"] == "1")
    }
}

private extension MHMutationWorkflowLoggerTests {
    func waitForEvents(
        in store: MHLogStore,
        count: Int,
        maximumAttempts: Int = Constants.maximumEventWaitAttempts
    ) async -> [MHLogEvent] {
        for _ in 0..<maximumAttempts {
            let events = await store.events()
            if events.count >= count {
                return events
            }

            try? await Task.sleep(
                nanoseconds: Constants.eventWaitDelayNanoseconds
            )
        }

        return await store.events()
    }
}
