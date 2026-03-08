import MHLogging

/// In-memory sink recorder for log-store and logger integration tests.
public actor MHLogSinkRecorder: MHLogSink {
    private var recordedEvents = [MHLogEvent]()

    public init() {
        // Intentionally empty.
    }

    public func write(_ event: MHLogEvent) async {
        await Task.yield()
        recordedEvents.append(event)
    }

    public func events() -> [MHLogEvent] {
        recordedEvents
    }
}
