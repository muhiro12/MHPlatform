import Foundation

/// In-memory ring buffer with optional fan-out to configured sinks.
public actor MHLogStore {
    private let policy: MHLogPolicy
    private let sinks: [any MHLogSink]
    private let encoder: JSONEncoder

    private var bufferedEvents = [MHLogEvent]()

    /// Creates a log store with retention policy and optional sink fan-out.
    public init(
        policy: MHLogPolicy = .default,
        sinks: [any MHLogSink] = []
    ) {
        self.policy = policy
        self.sinks = sinks
        self.encoder = MHLogJSONCodec.makeEncoder()
    }

    /// Records an event into the ring buffer and forwards it to configured sinks.
    public func record(_ event: MHLogEvent) async {
        guard event.level >= policy.minimumLevel else {
            return
        }

        bufferedEvents.append(event)
        trimIfNeeded()

        for sink in sinks {
            if policy.persistsToDisk == false,
               sink is MHJSONLLogSink {
                continue
            }
            await sink.write(event)
        }
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
        let values = filteredEvents(matching: query)
        let lines: [String] = values.compactMap { event in
            guard let data = try? encoder.encode(event) else {
                return nil
            }
            return String(data: data, encoding: .utf8)
        }
        return lines.joined(separator: "\n")
    }

    /// Clears all in-memory buffered events.
    public func clear() {
        bufferedEvents.removeAll(keepingCapacity: true)
    }
}

private extension MHLogStore {
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
        var values = bufferedEvents

        if let minimumLevel = query.minimumLevel {
            values = values.filter { event in
                event.level >= minimumLevel
            }
        }

        if let category = query.category {
            values = values.filter { event in
                event.category.localizedCaseInsensitiveContains(category)
            }
        }

        if let searchText = query.searchText {
            values = values.filter { event in
                event.message.localizedCaseInsensitiveContains(searchText)
                    || event.subsystem.localizedCaseInsensitiveContains(searchText)
                    || event.category.localizedCaseInsensitiveContains(searchText)
                    || event.source.file.localizedCaseInsensitiveContains(searchText)
                    || event.metadata.keys.contains { key in
                        key.localizedCaseInsensitiveContains(searchText)
                    }
                    || event.metadata.values.contains { value in
                        value.localizedCaseInsensitiveContains(searchText)
                    }
            }
        }

        if let limit = query.limit,
           limit > 0,
           values.count > limit {
            values = Array(values.suffix(limit))
        }

        return values
    }
}
