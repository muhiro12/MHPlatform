import Foundation

enum RouteExecutionDemoError: LocalizedError {
    case resolveFailed

    var errorDescription: String? {
        switch self {
        case .resolveFailed:
            return "Route could not be resolved."
        }
    }
}
