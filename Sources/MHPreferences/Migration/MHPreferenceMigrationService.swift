import Foundation

/// Runs preference-migration steps in declaration order while recording completion state.
public enum MHPreferenceMigrationService {
    private struct NonSendableErrorWrapper: CustomStringConvertible, Error, LocalizedError, Sendable {
        let message: String

        var description: String {
            message
        }

        var errorDescription: String? {
            message
        }
    }

    /// Executes migration steps sequentially and records each completed step ID.
    @preconcurrency
    public static func run(
        steps: [MHPreferenceMigrationStep],
        stateDescriptor: MHPreferenceMigrationStateDescriptor,
        stateStore: MHPreferenceStore = .init(),
        onEvent: @Sendable (MHPreferenceMigrationEvent) -> Void = { _ in () }
    ) async -> MHPreferenceMigrationOutcome {
        precondition(stepIDsAreUnique(in: steps))

        let completedDescriptor = stateDescriptor.completedStepIDsDescriptor
        var completedStepIDSet = Set(
            stateStore.codable(for: completedDescriptor) ?? []
        )
        var completedStepIDs = [String]()
        var skippedStepIDs = [String]()

        for step in steps {
            if completedStepIDSet.contains(step.id) {
                skippedStepIDs.append(step.id)
                onEvent(.stepSkipped(id: step.id))
                continue
            }

            onEvent(.stepStarted(id: step.id))

            do {
                try await step.action()
                completedStepIDSet.insert(step.id)
                stateStore.setCodable(
                    completedStepIDSet.sorted(),
                    for: completedDescriptor
                )
                completedStepIDs.append(step.id)
                onEvent(.stepSucceeded(id: step.id))
            } catch {
                onEvent(
                    .stepFailed(
                        id: step.id,
                        message: String(describing: error)
                    )
                )
                return .failed(
                    error: sendableError(from: error),
                    failedStepID: step.id,
                    completedStepIDs: completedStepIDs,
                    skippedStepIDs: skippedStepIDs
                )
            }
        }

        onEvent(.completed)
        return .succeeded(
            completedStepIDs: completedStepIDs,
            skippedStepIDs: skippedStepIDs
        )
    }
}

private extension MHPreferenceMigrationService {
    static func sendableError(
        from error: any Error
    ) -> any Error & Sendable {
        NonSendableErrorWrapper(
            message: String(describing: error)
        )
    }

    static func stepIDsAreUnique(
        in steps: [MHPreferenceMigrationStep]
    ) -> Bool {
        Set(steps.map(\.id)).count == steps.count
    }
}
