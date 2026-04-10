import Foundation

/// Session scope available in the diagnostics console.
public enum MHLogSessionScope: String, CaseIterable, Sendable {
    case current
    case previous
}

public extension MHLogSessionScope {
    /// User-facing title for the diagnostics console picker.
    var title: String {
        switch self {
        case .current:
            return "Current Session"
        case .previous:
            return "Previous Session"
        }
    }
}
