import Foundation
import MHPlatformUtilities
import SwiftData
import Testing

struct MHSwiftDataUtilitiesTests {
    @Test
    func persistentIdentifierCodecRejectsInvalidBase64() {
        #expect(throws: MHPersistentIdentifierCodecError.invalidBase64String) {
            _ = try PersistentIdentifier(base64Encoded: "not-a-base64")
        }
    }

    @Test
    func persistentIdentifierCodecRoundTripsInsertedModelIdentifier() throws {
        let context = try makeContext()
        let record = MHUtilityRecord(name: "record")
        context.insert(record)

        let encodedIdentifier = try MHPersistentIdentifierCodec.encode(
            record.persistentModelID
        )
        let extensionEncodedIdentifier = try record.persistentModelID.base64Encoded()
        let decodedIdentifier = try MHPersistentIdentifierCodec.decode(
            encodedIdentifier
        )
        let extensionDecodedIdentifier = try PersistentIdentifier(
            base64Encoded: encodedIdentifier
        )

        #expect(encodedIdentifier == extensionEncodedIdentifier)
        #expect(decodedIdentifier == record.persistentModelID)
        #expect(extensionDecodedIdentifier == record.persistentModelID)
        #expect(
            MHPersistentIdentifierCodec.stableIdentifier(for: record)
                == encodedIdentifier
        )
    }

    @Test
    func fetchFirstAppliesFetchLimit() throws {
        let context = try makeContext()
        context.insert(MHUtilityRecord(name: "Beta"))
        context.insert(MHUtilityRecord(name: "Alpha"))

        let descriptor = FetchDescriptor<MHUtilityRecord>(
            sortBy: [SortDescriptor<MHUtilityRecord>(\.name)]
        )
        let record = try context.fetchFirst(descriptor)

        #expect(record?.name == "Alpha")
    }

    @Test
    func fetchRandomReturnsNilWhenPopulationIsEmpty() throws {
        let context = try makeContext()
        let descriptor = FetchDescriptor<MHUtilityRecord>()

        #expect(try context.fetchRandom(descriptor) == nil)
    }

    @Test
    func fetchRandomReturnsMemberFromPopulation() throws {
        let context = try makeContext()
        context.insert(MHUtilityRecord(name: "Alpha"))
        context.insert(MHUtilityRecord(name: "Beta"))

        let descriptor = FetchDescriptor<MHUtilityRecord>()
        let record = try #require(try context.fetchRandom(descriptor))

        #expect(["Alpha", "Beta"].contains(record.name))
    }

    private func makeContext() throws -> ModelContext {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: MHUtilityRecord.self,
            configurations: configuration
        )
        return ModelContext(container)
    }
}
