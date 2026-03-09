import Foundation

/// Severity level for a log event.
public enum MHLogLevel: Int, CaseIterable, Codable, Comparable, Sendable {
    case debug = 10
    case info = 20
    case notice = 30
    case warning = 40
    case error = 50
    case critical = 60

    /// Stable lowercased level name.
    public var name: String {
        switch self {
        case .debug:
            return "debug"
        case .info:
            return "info"
        case .notice:
            return "notice"
        case .warning:
            return "warning"
        case .error:
            return "error"
        case .critical:
            return "critical"
        }
    }

    public static func < (
        lhs: Self,
        rhs: Self
    ) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
