import Foundation
@testable import SharedLibraryConsumer
import SwiftData
import Testing

@Suite
@MainActor
struct SharedStoreTests {
    @Model
    final class Entry {
        var title = ""

        init(title: String) {
            self.title = title
        }
    }

    @Test
    func missingGroupNeverSelectsAnotherDiskStore() throws {
        let assembly = SharedStoreAssembly(schema: .init([Entry.self])) { _ in nil }
        #expect(throws: CocoaError.self) { try assembly.host() }
        #expect(throws: CocoaError.self) { try assembly.extensionReader() }
        let preview = try assembly.preview()
        #expect(preview.configurations.first?.isStoredInMemoryOnly == true)
    }

    @Test
    func extensionReadsOnlyAfterHostCreation() throws {
        let group = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: group) }
        let assembly = SharedStoreAssembly(schema: .init([Entry.self]), cloud: .none) { _ in group }
        #expect(throws: CocoaError.self) { try assembly.extensionReader() }
        #expect(!FileManager.default.fileExists(atPath: group.path))
        do {
            let host = try assembly.host()
            host.mainContext.insert(Entry(title: "Saved"))
            try host.mainContext.save()
        }
        let reader = try assembly.extensionReader()
        #expect(try reader.mainContext.fetch(FetchDescriptor<Entry>()).map(\.title) == ["Saved"])
        #expect(reader.configurations.allSatisfy { !$0.allowsSave })
        let preview = try assembly.preview()
        #expect(try preview.mainContext.fetchCount(FetchDescriptor<Entry>()) == 0)
    }

    @Test
    func extensionLeavesAnOlderStoreReadableByItsOwner() throws {
        let group = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: group) }
        let old = SharedStoreAssembly(schema: .init([PriorJournalSchema.Entry.self]), cloud: .none) { _ in group }
        do {
            let host = try old.host()
            let entry = PriorJournalSchema.Entry(oldField: "Before migration")
            host.mainContext.insert(entry)
            try host.mainContext.save()
        }
        let current = SharedStoreAssembly(schema: .init([Entry.self]), cloud: .none) { _ in group }
        #expect(throws: (any Error).self) { try current.extensionReader() }
        let reader = try old.extensionReader()
        let entries = try reader.mainContext.fetch(FetchDescriptor<PriorJournalSchema.Entry>())
        #expect(entries.first?.oldField == "Before migration")
    }
}
