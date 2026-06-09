import Foundation

enum MHLogEventCollection {
    static func filteredEvents(
        in events: [MHLogEvent],
        matching query: MHLogQuery
    ) -> [MHLogEvent] {
        var values = events

        if let minimumLevel = query.minimumLevel {
            values = values.filter { event in
                event.level >= minimumLevel
            }
        }

        if let category = query.category {
            values = values.filter { event in
                matchesCategory(
                    event,
                    category: category
                )
            }
        }

        if let searchText = query.searchText {
            values = values.filter { event in
                matchesSearchText(
                    event,
                    searchText: searchText
                )
            }
        }

        if let limit = query.limit,
           limit > 0,
           values.count > limit {
            values = Array(values.suffix(limit))
        }

        return values
    }

    static func exportJSONLines(
        from events: [MHLogEvent],
        matching query: MHLogQuery
    ) -> String {
        let encoder = MHLogJSONCodec.makeEncoder()
        let filteredEvents = filteredEvents(
            in: events,
            matching: query
        )
        let lines: [String] = filteredEvents.compactMap { event in
            guard let data = try? encoder.encode(event) else {
                return nil
            }
            return String(bytes: data, encoding: .utf8)
        }

        return lines.joined(separator: "\n")
    }
}

private extension MHLogEventCollection {
    static func matchesCategory(
        _ event: MHLogEvent,
        category: String
    ) -> Bool {
        event.category.localizedCaseInsensitiveContains(category)
    }

    static func matchesSearchText(
        _ event: MHLogEvent,
        searchText: String
    ) -> Bool {
        searchableValues(for: event).contains { value in
            value.localizedCaseInsensitiveContains(searchText)
        }
    }

    static func searchableValues(
        for event: MHLogEvent
    ) -> [String] {
        [
            event.message,
            event.subsystem,
            event.category,
            event.source.file
        ] + Array(event.metadata.keys) + Array(event.metadata.values)
    }
}
