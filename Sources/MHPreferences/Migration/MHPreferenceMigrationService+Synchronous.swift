public extension MHPreferenceMigrationService {
    /// Runs synchronous steps in declaration order without scheduling a task.
    ///
    /// Rejects any unfinished async-only step before executing the plan. Completed
    /// async-only steps are skipped. Callers must serialize runs for the state domain.
    static func runSynchronously(
        steps: [MHPreferenceMigrationStep],
        stateDescriptor: MHPreferenceMigrationStateDescriptor,
        stateStore: MHPreferenceStore = .init(),
        onEvent: @Sendable (MHPreferenceMigrationEvent) -> Void = { _ in () }
    ) -> MHPreferenceMigrationOutcome {
        precondition(Set(steps.map(\.id)).count == steps.count)
        let completedDescriptor = stateDescriptor.completedStepIDsDescriptor
        var completedStepIDSet = Set(stateStore.codable(for: completedDescriptor) ?? [])

        if let unsupportedStep = steps.first(where: { step in
            step.synchronousAction == nil && completedStepIDSet.contains(step.id) == false
        }) {
            let error = MHPreferenceSynchronousMigrationError.asynchronousStep(id: unsupportedStep.id)
            onEvent(.stepFailed(id: unsupportedStep.id, message: String(describing: error)))
            return .failed(
                error: error,
                failedStepID: unsupportedStep.id,
                completedStepIDs: [],
                skippedStepIDs: []
            )
        }

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
                // Preflight guarantees an action for every unfinished step.
                try step.synchronousAction?()
                completedStepIDSet.insert(step.id)
                stateStore.setCodable(completedStepIDSet.sorted(), for: completedDescriptor)
                completedStepIDs.append(step.id)
                onEvent(.stepSucceeded(id: step.id))
            } catch {
                onEvent(.stepFailed(id: step.id, message: String(describing: error)))
                return .failed(
                    error: error,
                    failedStepID: step.id,
                    completedStepIDs: completedStepIDs,
                    skippedStepIDs: skippedStepIDs
                )
            }
        }

        onEvent(.completed)
        return .succeeded(completedStepIDs: completedStepIDs, skippedStepIDs: skippedStepIDs)
    }
}
