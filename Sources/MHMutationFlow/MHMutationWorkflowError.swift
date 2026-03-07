import Foundation

/// Default error vocabulary for `MHMutationWorkflow` convenience APIs.
public enum MHMutationWorkflowError: Error, Equatable, Sendable {
    /// Mutation operation failed before post-success steps started.
    case operation(String)

    /// A post-success step failed.
    case step(name: String, description: String)
}

extension MHMutationWorkflowError: LocalizedError, CustomStringConvertible {
    public var description: String {
        switch self {
        case .operation(let description):
            return description
        case let .step(name, description):
            if description.isEmpty {
                return "Mutation step \(name) failed."
            }
            return description
        }
    }

    public var errorDescription: String? {
        description
    }
}

extension MHMutationWorkflowError {
    init(failure: MHMutationFailure) {
        switch failure {
        case .operation(let description):
            self = .operation(description)
        case let .step(name, description):
            self = .step(
                name: name,
                description: description
            )
        }
    }
}
