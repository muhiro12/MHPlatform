import Foundation
import MHPersistenceMaintenance
import Testing

struct MHStoreMigratorTests {
    @Test
    func migrateIfNeeded_copies_legacy_main_and_sidecars() throws {
        let fileManager: FileManager = .default
        let sandboxURL = try makeSandboxDirectory(fileManager: fileManager)
        defer {
            try? fileManager.removeItem(at: sandboxURL)
        }

        let storeFileName = "Demo.store"
        let storeURLs = try makeStoreURLs(
            sandboxURL: sandboxURL,
            fileManager: fileManager,
            storeFileName: storeFileName
        )

        createLegacyStoreFiles(
            fileManager: fileManager,
            legacyStoreURL: storeURLs.legacyStoreURL,
            legacyDirectoryURL: storeURLs.legacyDirectoryURL,
            storeFileName: storeFileName,
            sidecars: ["shm", "wal"]
        )

        let result = try MHStoreMigrator.migrateIfNeeded(
            plan: .init(
                legacyStoreURL: storeURLs.legacyStoreURL,
                currentStoreURL: storeURLs.currentStoreURL
            ),
            fileManager: fileManager
        )

        switch result {
        case let .migrated(copiedFileNames, removedCurrentFileNames):
            #expect(
                copiedFileNames == expectedFileNames(
                    for: storeFileName,
                    sidecars: ["shm", "wal"]
                )
            )
            #expect(removedCurrentFileNames.isEmpty)
        case .skipped:
            Issue.record("Expected migration result.")
        }

        #expect(
            try sortedDirectoryNames(
                at: storeURLs.currentDirectoryURL,
                fileManager: fileManager
            ) == expectedFileNames(for: storeFileName, sidecars: ["shm", "wal"])
        )
        #expect(
            try sortedDirectoryNames(
                at: storeURLs.legacyDirectoryURL,
                fileManager: fileManager
            ) == expectedFileNames(for: storeFileName, sidecars: ["shm", "wal"])
        )
    }

    @Test
    func migrateIfNeeded_overwrites_current_files_and_removes_stale_sidecars() throws {
        let fileManager: FileManager = .default
        let sandboxURL = try makeSandboxDirectory(fileManager: fileManager)
        defer {
            try? fileManager.removeItem(at: sandboxURL)
        }

        let storeFileName = "Demo.store"
        let legacyDirectoryURL = sandboxURL.appendingPathComponent("legacy", isDirectory: true)
        let currentDirectoryURL = sandboxURL.appendingPathComponent("current", isDirectory: true)

        try fileManager.createDirectory(at: legacyDirectoryURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: currentDirectoryURL, withIntermediateDirectories: true)

        let legacyStoreURL = legacyDirectoryURL.appendingPathComponent(storeFileName)
        let currentStoreURL = currentDirectoryURL.appendingPathComponent(storeFileName)
        let legacyWalURL = legacyDirectoryURL.appendingPathComponent("\(storeFileName)-wal")
        let currentWalURL = currentDirectoryURL.appendingPathComponent("\(storeFileName)-wal")
        let currentShmURL = currentDirectoryURL.appendingPathComponent("\(storeFileName)-shm")

        let legacyData = Data("legacy".utf8)
        let staleData = Data("stale".utf8)
        #expect(fileManager.createFile(atPath: legacyStoreURL.path, contents: legacyData))
        #expect(fileManager.createFile(atPath: legacyWalURL.path, contents: legacyData))
        #expect(fileManager.createFile(atPath: currentStoreURL.path, contents: staleData))
        #expect(fileManager.createFile(atPath: currentWalURL.path, contents: staleData))
        #expect(fileManager.createFile(atPath: currentShmURL.path, contents: staleData))

        let result = try MHStoreMigrator.migrateIfNeeded(
            plan: .init(
                legacyStoreURL: legacyStoreURL,
                currentStoreURL: currentStoreURL
            ),
            fileManager: fileManager
        )

        switch result {
        case let .migrated(copiedFileNames, removedCurrentFileNames):
            #expect(copiedFileNames == expectedFileNames(for: storeFileName, sidecars: ["wal"]))
            #expect(
                removedCurrentFileNames == expectedFileNames(
                    for: storeFileName,
                    sidecars: ["shm", "wal"]
                )
            )
        case .skipped:
            Issue.record("Expected migration result.")
        }

        #expect(try Data(contentsOf: currentStoreURL) == legacyData)
        #expect(try Data(contentsOf: currentWalURL) == legacyData)
        #expect(fileManager.fileExists(atPath: currentShmURL.path) == false)
        #expect(
            try sortedDirectoryNames(
                at: currentDirectoryURL,
                fileManager: fileManager
            ) == expectedFileNames(for: storeFileName, sidecars: ["wal"])
        )
    }

    @Test
    func migrateIfNeeded_skips_when_locations_match() throws {
        let fileManager: FileManager = .default
        let sandboxURL = try makeSandboxDirectory(fileManager: fileManager)
        defer {
            try? fileManager.removeItem(at: sandboxURL)
        }

        let storeURL = sandboxURL.appendingPathComponent("Demo.store")
        #expect(fileManager.createFile(atPath: storeURL.path, contents: Data()))

        let result = try MHStoreMigrator.migrateIfNeeded(
            plan: .init(
                legacyStoreURL: storeURL,
                currentStoreURL: storeURL
            ),
            fileManager: fileManager
        )

        #expect(result == .skipped(.sameLocation))
    }

    @Test
    func migrateIfNeeded_skips_when_legacy_store_is_missing() throws {
        let fileManager: FileManager = .default
        let sandboxURL = try makeSandboxDirectory(fileManager: fileManager)
        defer {
            try? fileManager.removeItem(at: sandboxURL)
        }

        let legacyStoreURL = sandboxURL.appendingPathComponent("legacy/Demo.store")
        let currentStoreURL = sandboxURL.appendingPathComponent("current/Demo.store")

        let result = try MHStoreMigrator.migrateIfNeeded(
            plan: .init(
                legacyStoreURL: legacyStoreURL,
                currentStoreURL: currentStoreURL
            ),
            fileManager: fileManager
        )

        #expect(result == .skipped(.missingLegacyStore))
    }

    @Test
    func removeLegacyStoreFilesIfNeeded_removes_only_legacy_files() throws {
        let fileManager: FileManager = .default
        let sandboxURL = try makeSandboxDirectory(fileManager: fileManager)
        defer {
            try? fileManager.removeItem(at: sandboxURL)
        }

        let storeFileName = "Demo.store"
        let legacyDirectoryURL = sandboxURL.appendingPathComponent("legacy", isDirectory: true)
        let currentDirectoryURL = sandboxURL.appendingPathComponent("current", isDirectory: true)

        try fileManager.createDirectory(at: legacyDirectoryURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: currentDirectoryURL, withIntermediateDirectories: true)

        let legacyStoreURL = legacyDirectoryURL.appendingPathComponent(storeFileName)
        let currentStoreURL = currentDirectoryURL.appendingPathComponent(storeFileName)

        #expect(fileManager.createFile(atPath: legacyStoreURL.path, contents: Data()))
        #expect(
            fileManager.createFile(
                atPath: legacyDirectoryURL.appendingPathComponent("\(storeFileName)-shm").path,
                contents: Data()
            )
        )
        #expect(
            fileManager.createFile(
                atPath: legacyDirectoryURL.appendingPathComponent("\(storeFileName)-wal").path,
                contents: Data()
            )
        )
        #expect(fileManager.createFile(atPath: currentStoreURL.path, contents: Data()))

        let result = try MHStoreMigrator.removeLegacyStoreFilesIfNeeded(
            plan: .init(
                legacyStoreURL: legacyStoreURL,
                currentStoreURL: currentStoreURL
            ),
            fileManager: fileManager
        )

        switch result {
        case let .removed(fileNames):
            #expect(fileNames == expectedFileNames(for: storeFileName, sidecars: ["shm", "wal"]))
        case .skipped:
            Issue.record("Expected removed result.")
        }

        #expect(fileManager.fileExists(atPath: currentStoreURL.path))
        #expect(try sortedDirectoryNames(at: legacyDirectoryURL, fileManager: fileManager).isEmpty)
    }
}

private extension MHStoreMigratorTests {
    struct StoreURLs {
        let legacyDirectoryURL: URL
        let currentDirectoryURL: URL
        let legacyStoreURL: URL
        let currentStoreURL: URL
    }

    func makeSandboxDirectory(fileManager: FileManager) throws -> URL {
        let sandboxURL = fileManager.temporaryDirectory.appendingPathComponent(
            UUID().uuidString,
            isDirectory: true
        )
        try fileManager.createDirectory(
            at: sandboxURL,
            withIntermediateDirectories: true
        )
        return sandboxURL
    }

    func makeStoreURLs(
        sandboxURL: URL,
        fileManager: FileManager,
        storeFileName: String
    ) throws -> StoreURLs {
        let legacyDirectoryURL = sandboxURL.appendingPathComponent("legacy", isDirectory: true)
        let currentDirectoryURL = sandboxURL.appendingPathComponent("current", isDirectory: true)

        try fileManager.createDirectory(at: legacyDirectoryURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: currentDirectoryURL, withIntermediateDirectories: true)

        return .init(
            legacyDirectoryURL: legacyDirectoryURL,
            currentDirectoryURL: currentDirectoryURL,
            legacyStoreURL: legacyDirectoryURL.appendingPathComponent(storeFileName),
            currentStoreURL: currentDirectoryURL.appendingPathComponent(storeFileName)
        )
    }

    func createLegacyStoreFiles(
        fileManager: FileManager,
        legacyStoreURL: URL,
        legacyDirectoryURL: URL,
        storeFileName: String,
        sidecars: [String]
    ) {
        #expect(fileManager.createFile(atPath: legacyStoreURL.path, contents: Data()))
        for sidecar in sidecars {
            #expect(
                fileManager.createFile(
                    atPath: legacyDirectoryURL.appendingPathComponent(
                        "\(storeFileName)-\(sidecar)"
                    ).path,
                    contents: Data()
                )
            )
        }
    }

    func expectedFileNames(
        for storeFileName: String,
        sidecars: [String]
    ) -> [String] {
        ([storeFileName] + sidecars.map { sidecar in
            "\(storeFileName)-\(sidecar)"
        })
        .sorted()
    }

    func sortedDirectoryNames(
        at directoryURL: URL,
        fileManager: FileManager
    ) throws -> [String] {
        guard fileManager.fileExists(atPath: directoryURL.path) else {
            return []
        }
        return try fileManager.contentsOfDirectory(atPath: directoryURL.path).sorted()
    }
}
