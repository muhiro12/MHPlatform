import Foundation
import MHPersistenceMaintenance
import Testing

struct MHStoreMigratorDirectoryHandlingTests {
    @Test
    func migrateIfNeeded_ignores_matching_directories() throws {
        let fileManager: FileManager = .default
        let fixture = try makeFixture(fileManager: fileManager)
        defer {
            try? fileManager.removeItem(at: fixture.sandboxURL)
        }

        try seedMigrationInputs(
            fixture: fixture,
            fileManager: fileManager
        )

        let result = try MHStoreMigrator.migrateIfNeeded(
            plan: .init(
                legacyStoreURL: fixture.legacyStoreURL,
                currentStoreURL: fixture.currentStoreURL
            ),
            fileManager: fileManager
        )

        assertMigrationResult(
            result,
            expectedFileNames: fixture.expectedStoreFileNames
        )
        #expect(try Data(contentsOf: fixture.currentStoreURL) == fixture.legacyData)
        #expect(try Data(contentsOf: fixture.currentWalURL) == fixture.legacyData)

        assertCurrentContainerRemains(
            fixture: fixture,
            fileManager: fileManager
        )
    }

    @Test
    func removeLegacyStoreFilesIfNeeded_ignores_matching_directories() throws {
        let fileManager: FileManager = .default
        let fixture = try makeFixture(fileManager: fileManager)
        defer {
            try? fileManager.removeItem(at: fixture.sandboxURL)
        }

        try seedCleanupInputs(
            fixture: fixture,
            fileManager: fileManager
        )

        let result = try MHStoreMigrator.removeLegacyStoreFilesIfNeeded(
            plan: .init(
                legacyStoreURL: fixture.legacyStoreURL,
                currentStoreURL: fixture.currentStoreURL
            ),
            fileManager: fileManager
        )

        switch result {
        case let .removed(fileNames):
            #expect(fileNames == fixture.expectedStoreFileNames)
        case .skipped:
            Issue.record("Expected removed result.")
        }

        #expect(fileManager.fileExists(atPath: fixture.currentStoreURL.path))
        #expect(fileManager.fileExists(atPath: fixture.legacyContainerURL.path))
        #expect(fileManager.fileExists(atPath: fixture.legacyContainerMarkerURL.path))
    }
}

private extension MHStoreMigratorDirectoryHandlingTests {
    struct Fixture {
        let sandboxURL: URL
        let legacyData = Data("legacy".utf8)
        let staleData = Data("stale".utf8)
        private let storeFileName = "Demo.store"

        var legacyDirectoryURL: URL {
            sandboxURL.appendingPathComponent("legacy", isDirectory: true)
        }

        var currentDirectoryURL: URL {
            sandboxURL.appendingPathComponent("current", isDirectory: true)
        }

        var legacyStoreURL: URL {
            legacyDirectoryURL.appendingPathComponent(storeFileName)
        }

        var currentStoreURL: URL {
            currentDirectoryURL.appendingPathComponent(storeFileName)
        }

        var legacyWalURL: URL {
            legacyDirectoryURL.appendingPathComponent("\(storeFileName)-wal")
        }

        var currentWalURL: URL {
            currentDirectoryURL.appendingPathComponent("\(storeFileName)-wal")
        }

        var legacyContainerURL: URL {
            legacyDirectoryURL.appendingPathComponent(
                "\(storeFileName)-container",
                isDirectory: true
            )
        }

        var currentContainerURL: URL {
            currentDirectoryURL.appendingPathComponent(
                "\(storeFileName)-container",
                isDirectory: true
            )
        }

        var legacyContainerMarkerURL: URL {
            legacyContainerURL.appendingPathComponent("legacy.txt")
        }

        var currentContainerMarkerURL: URL {
            currentContainerURL.appendingPathComponent("current.txt")
        }

        var currentContainerLegacyMarkerURL: URL {
            currentContainerURL.appendingPathComponent("legacy.txt")
        }

        var expectedStoreFileNames: [String] {
            [storeFileName, "\(storeFileName)-wal"].sorted()
        }
    }

    func makeFixture(fileManager: FileManager) throws -> Fixture {
        let sandboxURL = fileManager.temporaryDirectory.appendingPathComponent(
            UUID().uuidString,
            isDirectory: true
        )
        try fileManager.createDirectory(
            at: sandboxURL,
            withIntermediateDirectories: true
        )

        let fixture = Fixture(sandboxURL: sandboxURL)
        try fileManager.createDirectory(
            at: fixture.legacyDirectoryURL,
            withIntermediateDirectories: true
        )
        try fileManager.createDirectory(
            at: fixture.currentDirectoryURL,
            withIntermediateDirectories: true
        )
        return fixture
    }

    func seedMigrationInputs(
        fixture: Fixture,
        fileManager: FileManager
    ) throws {
        createFile(
            fixture.legacyStoreURL,
            contents: fixture.legacyData,
            fileManager: fileManager
        )
        createFile(
            fixture.legacyWalURL,
            contents: fixture.legacyData,
            fileManager: fileManager
        )
        createFile(
            fixture.currentStoreURL,
            contents: fixture.staleData,
            fileManager: fileManager
        )
        createFile(
            fixture.currentWalURL,
            contents: fixture.staleData,
            fileManager: fileManager
        )

        try fileManager.createDirectory(
            at: fixture.legacyContainerURL,
            withIntermediateDirectories: true
        )
        try fileManager.createDirectory(
            at: fixture.currentContainerURL,
            withIntermediateDirectories: true
        )

        createFile(
            fixture.legacyContainerMarkerURL,
            contents: fixture.legacyData,
            fileManager: fileManager
        )
        createFile(
            fixture.currentContainerMarkerURL,
            contents: fixture.staleData,
            fileManager: fileManager
        )
    }

    func seedCleanupInputs(
        fixture: Fixture,
        fileManager: FileManager
    ) throws {
        createFile(
            fixture.legacyStoreURL,
            contents: Data(),
            fileManager: fileManager
        )
        createFile(
            fixture.legacyWalURL,
            contents: Data(),
            fileManager: fileManager
        )
        createFile(
            fixture.currentStoreURL,
            contents: Data(),
            fileManager: fileManager
        )

        try fileManager.createDirectory(
            at: fixture.legacyContainerURL,
            withIntermediateDirectories: true
        )
        createFile(
            fixture.legacyContainerMarkerURL,
            contents: Data(),
            fileManager: fileManager
        )
    }

    func createFile(
        _ fileURL: URL,
        contents: Data,
        fileManager: FileManager
    ) {
        #expect(
            fileManager.createFile(
                atPath: fileURL.path,
                contents: contents
            )
        )
    }

    func assertMigrationResult(
        _ result: MHStoreMigrationOutcome,
        expectedFileNames: [String]
    ) {
        switch result {
        case let .migrated(copiedFileNames, removedCurrentFileNames):
            #expect(copiedFileNames == expectedFileNames)
            #expect(removedCurrentFileNames == expectedFileNames)
        case .skipped:
            Issue.record("Expected migration result.")
        }
    }

    func assertCurrentContainerRemains(
        fixture: Fixture,
        fileManager: FileManager
    ) {
        #expect(fileManager.fileExists(atPath: fixture.currentContainerURL.path))
        #expect(fileManager.fileExists(atPath: fixture.currentContainerMarkerURL.path))
        #expect(
            fileManager.fileExists(
                atPath: fixture.currentContainerLegacyMarkerURL.path
            ) == false
        )
    }
}
