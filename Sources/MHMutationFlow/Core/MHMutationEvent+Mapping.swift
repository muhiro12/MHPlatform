public extension MHMutationEvent {
    /// Returns the same event while transforming only the succeeded value payload.
    func mapValue<MappedValue: Sendable>(
        _ transform: @Sendable (Value) -> MappedValue
    ) -> MHMutationEvent<MappedValue> {
        switch self {
        case let .started(mutation, attempt):
            return .started(
                mutation: mutation,
                attempt: attempt
            )
        case let .progress(progress):
            return .progress(progress)
        case let .succeeded(value, attempts, completedSteps):
            return .succeeded(
                value: transform(value),
                attempts: attempts,
                completedSteps: completedSteps
            )
        case let .failed(errorDescription, attempts, completedSteps, isRecoverable):
            return .failed(
                errorDescription: errorDescription,
                attempts: attempts,
                completedSteps: completedSteps,
                isRecoverable: isRecoverable
            )
        case let .cancelled(attempts, completedSteps):
            return .cancelled(
                attempts: attempts,
                completedSteps: completedSteps
            )
        }
    }
}
