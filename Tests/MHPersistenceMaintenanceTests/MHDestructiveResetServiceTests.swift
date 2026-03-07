import Foundation
import MHPersistenceMaintenance
import Testing

struct MHDestructiveResetServiceTests {
    @Test
    func run_executes_steps_in_order_and_emits_completion() async {
        let recorder = Recorder()

        let steps: [MHDestructiveResetStep] = [
            .init(name: "clear-cache") {
                recorder.append("action:clear-cache")
            },
            .init(name: "rebuild-index") {
                recorder.append("action:rebuild-index")
            }
        ]

        let outcome = await MHDestructiveResetService.run(steps: steps) { event in
            recorder.append("event:\(Self.eventDescription(event))")
        }

        switch outcome {
        case .succeeded(let completedSteps):
            #expect(completedSteps == ["clear-cache", "rebuild-index"])
        case .failed:
            Issue.record("Expected succeeded outcome.")
        }

        #expect(recorder.snapshot() == [
            "event:stepStarted:clear-cache",
            "action:clear-cache",
            "event:stepSucceeded:clear-cache",
            "event:stepStarted:rebuild-index",
            "action:rebuild-index",
            "event:stepSucceeded:rebuild-index",
            "event:completed"
        ])
    }

    @Test
    func run_stops_on_first_failure_and_reports_context() async {
        let recorder = Recorder()

        let steps: [MHDestructiveResetStep] = [
            .init(name: "clear-cache") {
                recorder.append("action:clear-cache")
            },
            .init(name: "wipe-store") {
                recorder.append("action:wipe-store")
                throw ResetError.failedStep
            },
            .init(name: "rebuild-index") {
                recorder.append("action:rebuild-index")
            }
        ]

        let outcome = await MHDestructiveResetService.run(steps: steps) { event in
            recorder.append("event:\(Self.eventDescription(event))")
        }

        switch outcome {
        case let .failed(error, failedStep, completedSteps):
            #expect(failedStep == "wipe-store")
            #expect(completedSteps == ["clear-cache"])
            #expect(String(describing: error) == "failedStep")
        case .succeeded:
            Issue.record("Expected failed outcome.")
        }

        #expect(recorder.snapshot() == [
            "event:stepStarted:clear-cache",
            "action:clear-cache",
            "event:stepSucceeded:clear-cache",
            "event:stepStarted:wipe-store",
            "action:wipe-store",
            "event:stepFailed:wipe-store:failedStep"
        ])
    }

    @Test
    func run_returns_success_for_empty_steps() async {
        let recorder = Recorder()

        let outcome = await MHDestructiveResetService.run(steps: []) { event in
            recorder.append("event:\(Self.eventDescription(event))")
        }

        switch outcome {
        case .succeeded(let completedSteps):
            #expect(completedSteps.isEmpty)
        case .failed:
            Issue.record("Expected succeeded outcome for empty steps.")
        }

        #expect(recorder.snapshot() == [
            "event:completed"
        ])
    }

    @Test
    func runThrowing_returns_completed_steps() async throws {
        let recorder = Recorder()

        let completedSteps = try await MHDestructiveResetService.runThrowing(
            steps: [
                .init(name: "clear-cache") {
                    recorder.append("action:clear-cache")
                },
                .init(name: "rebuild-index") {
                    recorder.append("action:rebuild-index")
                }
            ]
        ) { event in
            recorder.append("event:\(Self.eventDescription(event))")
        }

        #expect(completedSteps == ["clear-cache", "rebuild-index"])
        #expect(recorder.snapshot() == [
            "event:stepStarted:clear-cache",
            "action:clear-cache",
            "event:stepSucceeded:clear-cache",
            "event:stepStarted:rebuild-index",
            "action:rebuild-index",
            "event:stepSucceeded:rebuild-index",
            "event:completed"
        ])
    }

    @Test
    func runThrowing_throws_first_failure() async {
        let recorder = Recorder()

        do {
            try await MHDestructiveResetService.runThrowing(
                steps: [
                    .init(name: "clear-cache") {
                        recorder.append("action:clear-cache")
                    },
                    .init(name: "wipe-store") {
                        recorder.append("action:wipe-store")
                        throw ResetError.failedStep
                    },
                    .init(name: "rebuild-index") {
                        recorder.append("action:rebuild-index")
                    }
                ]
            ) { event in
                recorder.append("event:\(Self.eventDescription(event))")
            }
            Issue.record("Expected runThrowing to throw.")
        } catch {
            #expect(String(describing: error) == "failedStep")
        }

        #expect(recorder.snapshot() == [
            "event:stepStarted:clear-cache",
            "action:clear-cache",
            "event:stepSucceeded:clear-cache",
            "event:stepStarted:wipe-store",
            "action:wipe-store",
            "event:stepFailed:wipe-store:failedStep"
        ])
    }
}

private extension MHDestructiveResetServiceTests {
    enum ResetError: Error, Sendable {
        case failedStep
    }

    final class Recorder: @unchecked Sendable {
        private let lock = NSLock()
        private var entries = [String]()

        func append(_ entry: String) {
            lock.lock()
            entries.append(entry)
            lock.unlock()
        }

        func snapshot() -> [String] {
            lock.lock()
            defer {
                lock.unlock()
            }
            return entries
        }
    }

    static func eventDescription(_ event: MHDestructiveResetEvent) -> String {
        switch event {
        case .stepStarted(let name):
            return "stepStarted:\(name)"
        case .stepSucceeded(let name):
            return "stepSucceeded:\(name)"
        case let .stepFailed(name, message):
            return "stepFailed:\(name):\(message)"
        case .completed:
            return "completed"
        }
    }
}
