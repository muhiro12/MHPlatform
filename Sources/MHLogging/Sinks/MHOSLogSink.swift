import Foundation
import OSLog

/// OSLog sink for unified system logging.
public struct MHOSLogSink: MHLogSink {
    public init() {
        // Intentionally empty.
    }

    public func write(_ event: MHLogEvent) async {
        await Task.yield()

        let logger = Logger(
            subsystem: event.subsystem,
            category: event.category
        )
        let line = event.summaryLine
        logger.log(
            level: event.level.osLogType,
            "\(line, privacy: .public)"
        )
    }
}

private extension MHLogLevel {
    var osLogType: OSLogType {
        switch self {
        case .debug:
            return .debug
        case .info:
            return .info
        case .notice:
            return .default
        case .warning:
            return .error
        case .error:
            return .fault
        case .critical:
            return .fault
        }
    }
}
