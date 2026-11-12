#if DEBUG
import Foundation
@testable import SharedLibraryConsumer
import SwiftData
import Testing

@Suite
@MainActor
struct DevelopmentStoreTests {
    @Test
    func firstCreationSeedsOnlyTheLocalDevelopmentStore() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try DevelopmentStore(directory: directory, automaticallyInsertSamples: true)
        let configuration = try #require(store.container.configurations.first)
        #expect(configuration.url == directory.appending(path: "Development.store"))
        #expect(configuration.cloudKitContainerIdentifier == nil)
        #expect(configuration.groupAppContainerIdentifier == nil)
        #expect(!configuration.isStoredInMemoryOnly)
        #expect(try titles(in: ModelContext(store.container)) == JournalSamples.titles.sorted())
    }

    @Test
    func reopeningPreservesEditsWithoutAddingSamples() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        do {
            let store = try DevelopmentStore(directory: directory, automaticallyInsertSamples: true)
            let context = ModelContext(store.container)
            let entries = try context.fetch(FetchDescriptor<JournalEntry>())
            for entry in entries {
                context.delete(entry)
            }
            context.insert(JournalEntry(title: "My development edit"))
            try context.save()
        }
        let reopened = try DevelopmentStore(directory: directory, automaticallyInsertSamples: true)
        #expect(try titles(in: ModelContext(reopened.container)) == ["My development edit"])
    }

    @Test
    func reopeningAnIntentionallyEmptiedStoreDoesNotSeedAgain() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        do {
            let store = try DevelopmentStore(directory: directory, automaticallyInsertSamples: true)
            let context = ModelContext(store.container)
            for entry in try context.fetch(FetchDescriptor<JournalEntry>()) {
                context.delete(entry)
            }
            try context.save()
        }
        let reopened = try DevelopmentStore(directory: directory, automaticallyInsertSamples: true)
        #expect(try titles(in: ModelContext(reopened.container)).isEmpty)
    }

    @Test
    func optOutRemainsEmptyOnReopenAndAllowsExplicitInsertion() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        do {
            let store = try DevelopmentStore(directory: directory, automaticallyInsertSamples: false)
            #expect(try titles(in: ModelContext(store.container)).isEmpty)
        }
        let reopened = try DevelopmentStore(directory: directory, automaticallyInsertSamples: true)
        let context = ModelContext(reopened.container)
        #expect(try titles(in: context).isEmpty)
        try reopened.insertSamples(into: context)
        #expect(try titles(in: context) == JournalSamples.titles.sorted())
        #expect(throws: DevelopmentStore.InsertionError.nonemptyStore) {
            try reopened.insertSamples(into: context)
        }
    }

    @Test
    func disablingAutomaticInsertionPreservesExistingData() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        do {
            _ = try DevelopmentStore(directory: directory, automaticallyInsertSamples: true)
        }
        let reopened = try DevelopmentStore(directory: directory, automaticallyInsertSamples: false)
        #expect(try titles(in: ModelContext(reopened.container)) == JournalSamples.titles.sorted())
    }

    @Test
    func manualInsertionRejectsSharedHostAndExtensionContainers() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try DevelopmentStore(directory: directory, automaticallyInsertSamples: false)
        let shared = SharedStoreAssembly(schema: .init([JournalEntry.self]), cloud: .none) { _ in
            directory.appending(path: "Shared")
        }
        let host = try shared.host()
        let reader = try shared.extensionReader()
        for container in [host, reader] {
            let context = ModelContext(container)
            #expect(throws: DevelopmentStore.InsertionError.inappropriateTarget) {
                try store.insertSamples(into: context)
            }
            #expect(try titles(in: context).isEmpty)
        }
        #expect(try titles(in: ModelContext(store.container)).isEmpty)
    }

    @Test
    func manualInsertionDoesNotSaveOrDiscardPendingEdits() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try DevelopmentStore(directory: directory, automaticallyInsertSamples: false)
        let context = ModelContext(store.container)
        context.insert(JournalEntry(title: "Unsaved edit"))
        #expect(throws: DevelopmentStore.InsertionError.pendingChanges) {
            try store.insertSamples(into: context)
        }
        #expect(context.hasChanges)
        #expect(try titles(in: context) == ["Unsaved edit"])
        #expect(try titles(in: ModelContext(store.container)).isEmpty)
    }

    @Test
    func invalidDevelopmentLocationFailsWithoutFallback() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try Data("Not a directory".utf8).write(to: directory)
        #expect(throws: (any Error).self) {
            try DevelopmentStore(directory: directory, automaticallyInsertSamples: true)
        }
        #expect(try String(contentsOf: directory, encoding: .utf8) == "Not a directory")
    }

    @Test
    func previewReusesSampleValuesWithoutOpeningDevelopmentStorage() throws {
        let assembly = SharedStoreAssembly(schema: .init([JournalEntry.self])) { _ in
            Issue.record("Preview must not resolve an App Group")
            return nil
        }
        let preview = try assembly.preview()
        let context = ModelContext(preview)
        for title in JournalSamples.titles {
            context.insert(JournalEntry(title: title))
        }
        try context.save()
        #expect(try titles(in: context) == JournalSamples.titles.sorted())
        let anotherPreview = try assembly.preview()
        #expect(try titles(in: ModelContext(anotherPreview)).isEmpty)
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    }

    private func titles(in context: ModelContext) throws -> [String] {
        try context.fetch(FetchDescriptor<JournalEntry>()).map(\.title).sorted()
    }
}
#endif
