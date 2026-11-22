import Foundation
import MHPersistenceMaintenance
import Testing

struct MHStoreRelocationRecoveryTests {
    private enum ValidationError: Error {
        case rejected
    }

    private struct Fixture {
        let directory: URL
        let plan: MHStoreRelocationPlan
        let oldBytes = Data("old".utf8)
        let newBytes = Data("new".utf8)

        init(legacyName: String = "Demo.store", currentName: String = "Demo.store") throws {
            directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
            let legacy = directory.appending(path: "legacy", directoryHint: .isDirectory)
            let current = directory.appending(path: "current", directoryHint: .isDirectory)
            plan = .init(
                legacyStoreURL: legacy.appending(path: legacyName),
                currentStoreURL: current.appending(path: currentName)
            )
            for folder in [legacy, current] {
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            }
            try newBytes.write(to: plan.legacyStoreURL)
            try oldBytes.write(to: plan.currentStoreURL)
        }

        func sidecar(_ url: URL, _ suffix: String) -> URL {
            url.deletingLastPathComponent().appending(path: url.lastPathComponent + suffix)
        }

        func remove() throws {
            try FileManager.default.removeItem(at: directory)
        }
    }

    @Test
    func validationFailureRestoresDestinationAndAllowsRetry() throws {
        let fixture = try Fixture()
        defer { try? fixture.remove() }
        let plan = fixture.plan
        let currentWal = fixture.sidecar(plan.currentStoreURL, "-wal")
        let currentShm = fixture.sidecar(plan.currentStoreURL, "-shm")
        try fixture.oldBytes.write(to: currentWal)
        try fixture.newBytes.write(to: fixture.sidecar(plan.legacyStoreURL, "-shm"))

        #expect(throws: ValidationError.rejected) {
            try MHStoreRelocationService.relocateIfNeeded(plan: plan) { _, _ in
                try Data("validation".utf8).write(to: currentWal)
                throw ValidationError.rejected
            }
        }
        #expect(try Data(contentsOf: plan.currentStoreURL) == fixture.oldBytes)
        #expect(try Data(contentsOf: currentWal) == fixture.oldBytes)
        #expect(!FileManager.default.fileExists(atPath: currentShm.path))

        _ = try MHStoreRelocationService.relocateIfNeeded(plan: plan)
        #expect(try Data(contentsOf: plan.currentStoreURL) == fixture.newBytes)
        #expect(try Data(contentsOf: currentShm) == fixture.newBytes)
        #expect(!FileManager.default.fileExists(atPath: currentWal.path))
    }

    @Test
    func collidingDirectorySurvivesFailedInstallation() throws {
        let fixture = try Fixture()
        defer { try? fixture.remove() }
        let plan = fixture.plan
        try fixture.newBytes.write(to: fixture.sidecar(plan.legacyStoreURL, "-wal"))
        let directory = fixture.sidecar(plan.currentStoreURL, "-wal")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let marker = directory.appending(path: "keep")
        try fixture.oldBytes.write(to: marker)

        #expect(throws: (any Error).self) {
            try MHStoreRelocationService.relocateIfNeeded(plan: plan)
        }
        #expect(try Data(contentsOf: marker) == fixture.oldBytes)
        #expect(try Data(contentsOf: plan.currentStoreURL) == fixture.oldBytes)
    }

    @Test
    func differentStoreNamesUseDestinationBasename() throws {
        let fixture = try Fixture(legacyName: "Old.store", currentName: "New.store")
        defer { try? fixture.remove() }
        let plan = fixture.plan
        try fixture.newBytes.write(to: fixture.sidecar(plan.legacyStoreURL, "-wal"))
        let unrelated = plan.currentStoreURL.deletingLastPathComponent().appending(path: "Old.store")
        try fixture.oldBytes.write(to: unrelated)

        let outcome = try MHStoreRelocationService.relocateIfNeeded(plan: plan)
        #expect(outcome == .relocated(
            copiedFileNames: ["New.store", "New.store-wal"],
            removedCurrentFileNames: ["New.store"]
        ))
        #expect(try Data(contentsOf: unrelated) == fixture.oldBytes)
        #expect(try Data(contentsOf: plan.currentStoreURL) == fixture.newBytes)
        #expect(try Data(contentsOf: fixture.sidecar(plan.currentStoreURL, "-wal")) == fixture.newBytes)
    }

    @Test
    func sidecarCleanupFailureLeavesTheValidatedStoreReadyForNextStartup() throws {
        let fixture = try Fixture()
        defer { try? fixture.remove() }
        let plan = fixture.plan
        let legacyWal = fixture.sidecar(plan.legacyStoreURL, "-wal")
        let currentWal = fixture.sidecar(plan.currentStoreURL, "-wal")
        let manager = FileManager.default
        try manager.removeItem(at: plan.currentStoreURL)
        try fixture.newBytes.write(to: legacyWal)

        let relocation = try MHStoreRelocationService.relocateIfNeeded(plan: plan) { url, _ in
            guard try Data(contentsOf: url) == fixture.newBytes else {
                throw ValidationError.rejected
            }
        }
        #expect(relocation == .relocated(
            copiedFileNames: ["Demo.store", "Demo.store-wal"],
            removedCurrentFileNames: []
        ))

        try manager.setAttributes([.immutable: true], ofItemAtPath: legacyWal.path)
        defer { try? manager.setAttributes([.immutable: false], ofItemAtPath: legacyWal.path) }
        #expect(throws: (any Error).self) {
            try MHStoreRelocationService.removeLegacyStoreFilesIfNeeded(plan: plan)
        }

        #expect(!manager.fileExists(atPath: plan.legacyStoreURL.path))
        #expect(manager.fileExists(atPath: legacyWal.path))
        #expect(try MHStoreRelocationService.relocateIfNeeded(plan: plan) == .skipped(.missingLegacyStore))
        #expect(try Data(contentsOf: plan.currentStoreURL) == fixture.newBytes)
        #expect(try Data(contentsOf: currentWal) == fixture.newBytes)
    }

    @Test
    func overlappingStoreNamesCannotRemoveEitherStore() throws {
        let fixture = try Fixture()
        defer { try? fixture.remove() }
        let legacy = fixture.plan.legacyStoreURL
        let current = fixture.sidecar(legacy, "-copy")
        try fixture.oldBytes.write(to: current)
        let plan = MHStoreRelocationPlan(legacyStoreURL: legacy, currentStoreURL: current)

        #expect(throws: CocoaError.self) {
            try MHStoreRelocationService.relocateIfNeeded(plan: plan)
        }
        #expect(throws: CocoaError.self) {
            try MHStoreRelocationService.removeLegacyStoreFilesIfNeeded(plan: plan)
        }
        #expect(try Data(contentsOf: legacy) == fixture.newBytes)
        #expect(try Data(contentsOf: current) == fixture.oldBytes)
    }

    @Test(arguments: [true, false])
    func equivalentLocationsPreserveSource(relocate: Bool) throws {
        let fixture = try Fixture()
        defer { try? fixture.remove() }
        let legacy = fixture.plan.legacyStoreURL
        let alias = fixture.directory.appending(path: "alias")
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: legacy.deletingLastPathComponent())
        let plan = MHStoreRelocationPlan(
            legacyStoreURL: legacy,
            currentStoreURL: alias.appending(path: legacy.lastPathComponent)
        )

        if relocate {
            #expect(try MHStoreRelocationService.relocateIfNeeded(plan: plan) == .skipped(.sameLocation))
        } else {
            #expect(try MHStoreRelocationService.removeLegacyStoreFilesIfNeeded(plan: plan) == .skipped(.sameLocation))
        }
        #expect(try Data(contentsOf: legacy) == fixture.newBytes)
    }
}
