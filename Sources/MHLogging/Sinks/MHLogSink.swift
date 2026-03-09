import Foundation

/// Pluggable sink interface used by `MHLogStore`.
public protocol MHLogSink: Sendable {
    func write(_ event: MHLogEvent) async
}
