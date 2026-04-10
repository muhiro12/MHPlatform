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
            return String(data: data, encoding: .utf8)
        }

        return lines.joined(separator: "\n")
    }
}
