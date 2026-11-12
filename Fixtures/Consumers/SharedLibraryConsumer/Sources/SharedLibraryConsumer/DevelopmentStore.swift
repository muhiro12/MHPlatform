#if DEBUG
import Foundation
import SwiftData

/// App-owned recipe; create one owner at startup with a dedicated local directory.
@MainActor
struct DevelopmentStore {
    enum InsertionError: Error {
        case inappropriateTarget
        case pendingChanges
        case nonemptyStore
    }

    let container: ModelContainer

    init(directory: URL, automaticallyInsertSamples: Bool) throws {
        let url = directory.appending(path: "Development.store")
        let isFirstCreation = !FileManager.default.fileExists(atPath: url.path)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let schema = Schema([JournalEntry.self])
        container = try .init(
            for: schema,
            configurations: [.init(schema: schema, url: url, cloudKitDatabase: .none)]
        )

        // Store creation records initialization even when samples are disabled or later deleted.
        if isFirstCreation, automaticallyInsertSamples {
            try insertSamples(into: ModelContext(container))
        }
    }

    func insertSamples(into context: ModelContext) throws {
        // Only this owner's local container is eligible, never an arbitrary host/extension container.
        guard context.container === container else {
            throw InsertionError.inappropriateTarget
        }
        guard !context.hasChanges else {
            throw InsertionError.pendingChanges
        }
        guard try context.fetchCount(FetchDescriptor<JournalEntry>()) == 0 else {
            throw InsertionError.nonemptyStore
        }

        for title in JournalSamples.titles {
            context.insert(JournalEntry(title: title))
        }
        do {
            try context.save()
        } catch {
            // The guard above ensures rollback cannot discard an unrelated pending edit.
            context.rollback()
            throw error
        }
    }
}
#endif
