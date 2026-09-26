/// A migration plan that cannot be executed synchronously.
public enum MHPreferenceSynchronousMigrationError: Error, Equatable, Sendable {
    /// An unfinished step has only an asynchronous action.
    case asynchronousStep(id: String)
}
