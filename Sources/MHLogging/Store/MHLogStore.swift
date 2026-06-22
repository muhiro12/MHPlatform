import Foundation

/// In-memory ring buffer with optional fan-out to configured sinks.
public actor MHLogStore {
    private let policy: MHLogPolicy
    private let runtimeState: MHLogRuntimeState?
    private let sinks: [any MHLogSink]

    private var bufferedEvents = [MHLogEvent]()

    /// Creates a log store with retention policy and optional sink fan-out.
    public init(
        policy: MHLogPolicy = .default,
        runtimeState: MHLogRuntimeState? = nil,
        sinks: [any MHLogSink] = [],
        initialEvents: [MHLogEvent] = []
    ) {
        var trimmedEvents = initialEvents
        let overflow = trimmedEvents.count - policy.maximumInMemoryEvents
        if overflow > 0 {
            trimmedEvents.removeFirst(overflow)
        }

        self.policy = policy
        self.runtimeState = runtimeState
        self.sinks = sinks
        self.bufferedEvents = trimmedEvents
    }

    /// Records an event into the ring buffer and forwards it to configured sinks.
    public func record(_ event: MHLogEvent) async {
        guard shouldCapture(event.level) else {
            return
        }

        bufferedEvents.append(event)
        sortBufferedEvents()
        trimIfNeeded()

        for sink in sinks {
            await sink.write(event)
        }
    }

    /// Seeds buffered events without re-fanning them to sinks.
    public func seed(_ events: [MHLogEvent]) {
        guard events.isEmpty == false else {
            return
        }

        var knownEvents = Set(bufferedEvents)

        for event in events where knownEvents.insert(event).inserted {
            bufferedEvents.append(event)
        }

        bufferedEvents.sort { lhs, rhs in
            lhs.timestamp < rhs.timestamp
        }
        trimIfNeeded()
    }

    /// Returns all buffered events in chronological order.
    public func events() -> [MHLogEvent] {
        bufferedEvents
    }

    /// Returns buffered events filtered by `query`.
    public func events(matching query: MHLogQuery) -> [MHLogEvent] {
        filteredEvents(matching: query)
    }

    /// Exports filtered events as JSON Lines text.
    public func exportJSONLines(
        matching query: MHLogQuery = .init()
    ) -> String {
        MHLogEventCollection.exportJSONLines(
            from: bufferedEvents,
            matching: query
        )
    }

    /// Clears all in-memory buffered events.
    public func clear() {
        bufferedEvents.removeAll(keepingCapacity: true)
    }
}

private extension MHLogStore {
    func shouldCapture(_ level: MHLogLevel) -> Bool {
        if let runtimeState {
            return runtimeState.shouldCapture(level)
        }

        return level >= policy.minimumLevel
    }

    func sortBufferedEvents() {
        bufferedEvents.sort { lhs, rhs in
            lhs.timestamp < rhs.timestamp
        }
    }

    func trimIfNeeded() {
        let overflow = bufferedEvents.count - policy.maximumInMemoryEvents
        guard overflow > 0 else {
            return
        }
        bufferedEvents.removeFirst(overflow)
    }

    func filteredEvents(
        matching query: MHLogQuery
    ) -> [MHLogEvent] {
        MHLogEventCollection.filteredEvents(
            in: bufferedEvents,
            matching: query
        )
    }
}
