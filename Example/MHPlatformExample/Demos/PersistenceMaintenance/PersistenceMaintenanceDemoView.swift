import Foundation
import MHPlatform
import SwiftUI

struct PersistenceMaintenanceDemoView: View {
    @State private var resetStatus = "No reset run yet"
    @State private var shouldFailReset = false
    @State private var resetEvents = [String]()

    var body: some View {
        NavigationStack {
            List {
                resetSection
            }
            .navigationTitle("Persistence")
        }
    }
}

private extension PersistenceMaintenanceDemoView {
    enum DemoError: Error {
        case simulatedResetFailure
    }

    final class EventRecorder: @unchecked Sendable {
        private let lock = NSLock()
        nonisolated(unsafe) private var values = [String]()

        nonisolated
        func append(_ value: String) {
            lock.lock()
            values.append(value)
            lock.unlock()
        }

        nonisolated
        func snapshot() -> [String] {
            lock.lock()
            defer {
                lock.unlock()
            }
            return values
        }
    }

    var resetSection: some View {
        Section("Destructive reset") {
            Toggle("Simulate step failure", isOn: $shouldFailReset)

            Button("Run reset demo") {
                Task {
                    let result = await runResetDemo(shouldFail: shouldFailReset)
                    resetStatus = result
                }
            }

            Text(resetStatus)
                .font(.footnote)
                .foregroundStyle(.secondary)

            if resetEvents.isEmpty == false {
                ForEach(resetEvents, id: \.self) { event in
                    Text(event)
                        .font(.footnote)
                }
            }
        }
    }

    nonisolated
    static func eventDescription(_ event: MHDestructiveResetEvent) -> String {
        switch event {
        case .stepStarted(let name):
            return "stepStarted(\(name))"
        case .stepSucceeded(let name):
            return "stepSucceeded(\(name))"
        case let .stepFailed(name, message):
            return "stepFailed(\(name)): \(message)"
        case .completed:
            return "completed"
        }
    }

    func runResetDemo(shouldFail: Bool) async -> String {
        let recorder = Self.EventRecorder()

        let outcome = await MHDestructiveResetService.run(
            steps: [
                .init(name: "clear-cache") {
                    // no-op
                },
                .init(name: "delete-store") {
                    if shouldFail {
                        throw DemoError.simulatedResetFailure
                    }
                },
                .init(name: "rebuild-index") {
                    // no-op
                }
            ]
        ) { event in
            recorder.append(
                Self.eventDescription(event)
            )
        }

        resetEvents = recorder.snapshot()

        switch outcome {
        case .succeeded(let completedSteps):
            return "succeeded completed=\(completedSteps)"
        case let .failed(error, failedStep, completedSteps):
            return "failed step=\(failedStep) completed=\(completedSteps) error=\(error)"
        }
    }
}

#Preview {
    PersistenceMaintenanceDemoView()
}
