import Foundation
import MHPreferences

actor MHLogSessionSnapshotSink: MHLogSink {
    struct Seed {
        let currentKey: MHCodablePreferenceKey<StoredSnapshot>
        let previousKey: MHCodablePreferenceKey<StoredSnapshot>
        let currentEvents: [MHLogEvent]
        let previousEvents: [MHLogEvent]
    }

    struct StoredSnapshot: Codable, Equatable, Sendable {
        let sessionIdentifier: UUID
        let events: [MHLogEvent]
    }

    static let processSessionIdentifier = UUID()

    private let currentKey: MHCodablePreferenceKey<StoredSnapshot>
    private let previousKey: MHCodablePreferenceKey<StoredSnapshot>
    private let snapshotStore: MHPreferenceStore
    private let sessionIdentifier: UUID

    private var currentEvents: [MHLogEvent]
    private var previousEvents: [MHLogEvent]

    init(
        seed: Seed,
        snapshotStore: MHPreferenceStore,
        sessionIdentifier: UUID
    ) {
        self.currentKey = seed.currentKey
        self.previousKey = seed.previousKey
        self.snapshotStore = snapshotStore
        self.sessionIdentifier = sessionIdentifier
        self.currentEvents = seed.currentEvents
        self.previousEvents = seed.previousEvents
    }

    static func makeSeed(
        snapshotStorageKeys: MHLogSnapshotStorageKeys,
        snapshotStore: MHPreferenceStore,
        sessionIdentifier: UUID
    ) -> Seed {
        let currentKey = MHCodablePreferenceKey<StoredSnapshot>(
            storageKey: snapshotStorageKeys.current.storageKey
        )
        let previousKey = MHCodablePreferenceKey<StoredSnapshot>(
            storageKey: snapshotStorageKeys.previous.storageKey
        )

        let storedCurrentSnapshot = snapshotStore.codable(for: currentKey)
        let storedPreviousSnapshot = snapshotStore.codable(for: previousKey)

        let currentSnapshot: StoredSnapshot
        let previousSnapshot: StoredSnapshot?

        if let storedCurrentSnapshot {
            if storedCurrentSnapshot.sessionIdentifier == sessionIdentifier {
                currentSnapshot = storedCurrentSnapshot
                previousSnapshot = storedPreviousSnapshot
            } else {
                currentSnapshot = .init(
                    sessionIdentifier: sessionIdentifier,
                    events: []
                )
                previousSnapshot = storedCurrentSnapshot
            }
        } else {
            currentSnapshot = .init(
                sessionIdentifier: sessionIdentifier,
                events: []
            )
            previousSnapshot = storedPreviousSnapshot
        }

        snapshotStore.setCodable(
            currentSnapshot,
            for: currentKey
        )
        snapshotStore.setCodable(
            previousSnapshot,
            for: previousKey
        )

        return .init(
            currentKey: currentKey,
            previousKey: previousKey,
            currentEvents: currentSnapshot.events,
            previousEvents: previousSnapshot?.events ?? []
        )
    }

    func write(_ event: MHLogEvent) async {
        await Task.yield()

        currentEvents.append(event)
        persistCurrentSnapshot()
    }

    func clear() {
        currentEvents.removeAll(keepingCapacity: true)
        previousEvents.removeAll(keepingCapacity: true)
        snapshotStore.remove(currentKey)
        snapshotStore.remove(previousKey)
    }
}

private extension MHLogSessionSnapshotSink {
    func persistCurrentSnapshot() {
        let currentSnapshot = StoredSnapshot(
            sessionIdentifier: sessionIdentifier,
            events: currentEvents
        )
        snapshotStore.setCodable(
            currentSnapshot,
            for: currentKey
        )
    }
}
