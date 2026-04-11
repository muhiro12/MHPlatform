import Foundation
@testable import MHLogging
import MHPreferences
import Testing

@MainActor
struct MHLoggingBootstrapTests {
    private enum Constants {
        static let previousSessionExportLineCount = 2
    }

    @Test
    func bootstrap_without_snapshot_key_stays_memory_only() async {
        let bootstrap = MHLoggingBootstrap(
            captureLevel: .warning,
            subsystem: "tests.bootstrap"
        )
        let logger = bootstrap.logger(
            category: "MemoryOnly",
            source: #fileID
        )

        await logger.logImmediately(.warning, "keep-warning")

        let currentEvents = await bootstrap.events(in: .current)
        let previousEvents = await bootstrap.events(in: .previous)

        #expect(currentEvents.map(\.message) == ["keep-warning"])
        #expect(previousEvents.isEmpty)
        #expect(bootstrap.hasPreviousSession == false)
    }

    @Test
    func bootstrap_promotes_last_session_snapshot_to_previous_session() async throws {
        try await exerciseSnapshotPromotion()
    }

    @Test
    func bootstrap_same_session_restores_current_snapshot_without_promoting_previous() async throws {
        let suiteName = "MHLoggingBootstrapTests.restore.\(UUID().uuidString)"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        userDefaults.removePersistentDomain(forName: suiteName)
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }

        let snapshotStore = MHPreferenceStore(userDefaults: userDefaults)
        let snapshotStorageDescriptors = makeSnapshotStorageDescriptors(
            baseStorageKey: "opaque.bootstrap.restore"
        )
        let sessionIdentifier = UUID()

        let firstBootstrap = makeBootstrap(
            snapshotStorageDescriptors: snapshotStorageDescriptors,
            snapshotStore: snapshotStore,
            sessionIdentifier: sessionIdentifier
        )
        let firstLogger = firstBootstrap.logger(
            category: "Restore",
            source: #fileID
        )
        await firstLogger.logImmediately(.warning, "keep-warning")

        let restoredBootstrap = makeBootstrap(
            snapshotStorageDescriptors: snapshotStorageDescriptors,
            snapshotStore: snapshotStore,
            sessionIdentifier: sessionIdentifier
        )

        #expect(restoredBootstrap.hasPreviousSession == false)
        #expect(
            await restoredBootstrap.events(in: .current).map(\.message) == [
                "keep-warning"
            ]
        )
        #expect(await restoredBootstrap.events(in: .previous).isEmpty)
    }

    @Test
    func bootstrap_clear_removes_current_and_previous_session_snapshots() async throws {
        let suiteName = "MHLoggingBootstrapTests.clear.\(UUID().uuidString)"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        userDefaults.removePersistentDomain(forName: suiteName)
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }

        let snapshotStore = MHPreferenceStore(userDefaults: userDefaults)
        let snapshotStorageDescriptors = makeSnapshotStorageDescriptors(
            baseStorageKey: "opaque.bootstrap.clear"
        )

        let firstBootstrap = makeBootstrap(
            snapshotStorageDescriptors: snapshotStorageDescriptors,
            snapshotStore: snapshotStore,
            sessionIdentifier: UUID()
        )
        let firstLogger = firstBootstrap.logger(
            category: "Clear",
            source: #fileID
        )
        await firstLogger.logImmediately(.warning, "keep-warning")

        let secondBootstrap = makeBootstrap(
            snapshotStorageDescriptors: snapshotStorageDescriptors,
            snapshotStore: snapshotStore,
            sessionIdentifier: UUID()
        )
        let secondLogger = secondBootstrap.logger(
            category: "Clear",
            source: #fileID
        )
        await secondLogger.logImmediately(.warning, "current-warning")

        await secondBootstrap.clear()

        let restoredBootstrap = makeBootstrap(
            snapshotStorageDescriptors: snapshotStorageDescriptors,
            snapshotStore: snapshotStore,
            sessionIdentifier: UUID()
        )

        #expect(await restoredBootstrap.events(in: .current).isEmpty)
        #expect(await restoredBootstrap.events(in: .previous).isEmpty)
        #expect(restoredBootstrap.hasPreviousSession == false)
    }

    @Test
    func bootstrap_snapshot_descriptors_use_default_selection() async throws {
        let suiteName = "MHLoggingBootstrapTests.defaultSelection.\(UUID().uuidString)"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        userDefaults.removePersistentDomain(forName: suiteName)
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }

        let snapshotStorageDescriptors = makeSnapshotStorageDescriptors(
            baseStorageKey: "opaque.bootstrap.selection",
            defaultSelection: .suite("  \(suiteName)\n")
        )
        let bootstrap = MHLoggingBootstrap(
            captureLevel: .warning,
            subsystem: "tests.bootstrap",
            snapshotStorageDescriptors: snapshotStorageDescriptors
        )
        let logger = bootstrap.logger(
            category: "Selection",
            source: #fileID
        )

        await logger.logImmediately(.warning, "keep-warning")

        #expect(
            userDefaults.object(
                forKey: snapshotStorageDescriptors.current.storageKey
            )
            is Data
        )
    }
}

private extension MHLoggingBootstrapTests {
    func exerciseSnapshotPromotion() async throws {
        let suiteName = "MHLoggingBootstrapTests.promote.\(UUID().uuidString)"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        userDefaults.removePersistentDomain(forName: suiteName)
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }

        let snapshotStore = MHPreferenceStore(userDefaults: userDefaults)
        let snapshotStorageDescriptors = makeSnapshotStorageDescriptors(
            baseStorageKey: "opaque.bootstrap.promote"
        )
        let firstBootstrap = makeBootstrap(
            snapshotStorageDescriptors: snapshotStorageDescriptors,
            snapshotStore: snapshotStore,
            sessionIdentifier: UUID()
        )
        let firstLogger = firstBootstrap.logger(category: "Promote", source: #fileID)
        await recordPromotionSeed(with: firstBootstrap, logger: firstLogger)

        let secondBootstrap = makeBootstrap(
            snapshotStorageDescriptors: snapshotStorageDescriptors,
            snapshotStore: snapshotStore,
            sessionIdentifier: UUID()
        )
        await assertInitialPromotionState(of: secondBootstrap)
        let secondLogger = secondBootstrap.logger(category: "Promote", source: #fileID)
        let previousSnapshotBeforeWrite = userDefaults.object(
            forKey: snapshotStorageDescriptors.previous.storageKey
        ) as? Data
        await secondLogger.logImmediately(.warning, "current-warning")

        await assertMessages(in: secondBootstrap, scope: .current, expected: ["current-warning"])
        await assertMessages(
            in: secondBootstrap,
            scope: .previous,
            expected: ["keep-warning", "keep-info"]
        )
        await assertExportedLineCount(
            in: secondBootstrap,
            scope: .previous,
            count: Constants.previousSessionExportLineCount
        )
        assertSnapshotStorage(
            in: userDefaults,
            previousSnapshotBeforeWrite: previousSnapshotBeforeWrite,
            snapshotStorageDescriptors: snapshotStorageDescriptors
        )
    }

    func makeBootstrap(
        snapshotStorageDescriptors: MHLogSnapshotStorageDescriptors,
        snapshotStore: MHPreferenceStore,
        sessionIdentifier: UUID
    ) -> MHLoggingBootstrap {
        MHLoggingBootstrap(
            captureLevel: .warning,
            policy: nil,
            subsystem: "tests.bootstrap",
            snapshotStorageDescriptors: snapshotStorageDescriptors,
            snapshotStore: snapshotStore,
            additionalSinks: [],
            sessionIdentifier: sessionIdentifier
        )
    }

    func recordPromotionSeed(
        with bootstrap: MHLoggingBootstrap,
        logger: MHLogger
    ) async {
        await logger.logImmediately(.info, "skip-info")
        await logger.logImmediately(.warning, "keep-warning")
        bootstrap.captureLevel = .info
        await logger.logImmediately(.info, "keep-info")
    }

    func assertInitialPromotionState(
        of bootstrap: MHLoggingBootstrap
    ) async {
        #expect(bootstrap.hasPreviousSession)
        await assertMessages(in: bootstrap, scope: .current, expected: [])
        await assertMessages(
            in: bootstrap,
            scope: .previous,
            expected: ["keep-warning", "keep-info"]
        )
    }

    func assertMessages(
        in bootstrap: MHLoggingBootstrap,
        scope: MHLogSessionScope,
        expected: [String]
    ) async {
        let events = await bootstrap.events(in: scope)

        #expect(events.map(\.message) == expected)
    }

    func assertExportedLineCount(
        in bootstrap: MHLoggingBootstrap,
        scope: MHLogSessionScope,
        count: Int
    ) async {
        let jsonLines = await bootstrap.exportJSONLines(in: scope)

        #expect(jsonLines.split(whereSeparator: \.isNewline).count == count)
    }

    func makeSnapshotStorageDescriptors(
        baseStorageKey: String,
        defaultSelection: MHUserDefaultsSelection = .standard
    ) -> MHLogSnapshotStorageDescriptors {
        .init(
            current: .init(
                storageKey: "\(baseStorageKey).current-session",
                defaultSelection: defaultSelection
            ),
            previous: .init(
                storageKey: "\(baseStorageKey).previous-session",
                defaultSelection: defaultSelection
            )
        )
    }

    func assertNoDerivedSnapshotKeys(
        in userDefaults: UserDefaults,
        snapshotStorageDescriptors: MHLogSnapshotStorageDescriptors
    ) {
        let derivedKeys = [
            "\(snapshotStorageDescriptors.current.storageKey).current",
            "\(snapshotStorageDescriptors.current.storageKey).previous",
            "\(snapshotStorageDescriptors.previous.storageKey).current",
            "\(snapshotStorageDescriptors.previous.storageKey).previous"
        ]

        for derivedKey in derivedKeys {
            #expect(userDefaults.object(forKey: derivedKey) == nil)
        }
    }

    func assertSnapshotStorage(
        in userDefaults: UserDefaults,
        previousSnapshotBeforeWrite: Data?,
        snapshotStorageDescriptors: MHLogSnapshotStorageDescriptors
    ) {
        let previousSnapshotAfterWrite = userDefaults.object(
            forKey: snapshotStorageDescriptors.previous.storageKey
        ) as? Data

        #expect(previousSnapshotBeforeWrite == previousSnapshotAfterWrite)
        #expect(
            userDefaults.object(
                forKey: snapshotStorageDescriptors.current.storageKey
            )
            != nil
        )
        assertNoDerivedSnapshotKeys(
            in: userDefaults,
            snapshotStorageDescriptors: snapshotStorageDescriptors
        )
    }
}
