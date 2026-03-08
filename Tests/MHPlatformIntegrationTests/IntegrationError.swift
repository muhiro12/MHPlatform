import Foundation

enum IntegrationError: Error, LocalizedError {
    case temporaryFailure

    var errorDescription: String? {
        switch self {
        case .temporaryFailure:
            return "temporaryFailure"
        }
    }
}
