import Foundation
import MHPreferences

actor MHLogSessionSnapshotSink: MHLogSink {
    struct Seed {
        let currentKey: MHCodablePreferenceDescriptor<StoredSnapshot>
        let previousKey: MHCodablePreferenceDescriptor<StoredSnapshot>
        let currentEvents: [MHLogEvent]
        let previousEvents: [MHLogEvent]
    }

    struct StoredSnapshot: Codable, Equatable, Sendable {
        let sessionIdentifier: UUID
        let events: [MHLogEvent]
    }

    static let processSessionIdentifier = UUID()

    private let currentKey: MHCodablePreferenceDescriptor<StoredSnapshot>
    private let previousKey: MHCodablePreferenceDescriptor<StoredSnapshot>
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
        snapshotStorageDescriptors: MHLogSnapshotStorageDescriptors,
        snapshotStore: MHPreferenceStore,
        sessionIdentifier: UUID
    ) -> Seed {
        let resolvedCurrentKey = MHCodablePreferenceDescriptor<StoredSnapshot>(
            storageKey: snapshotStorageDescriptors.current.storageKey,
            defaultSelection: snapshotStorageDescriptors.current.defaultSelection
        )
        let resolvedPreviousKey = MHCodablePreferenceDescriptor<StoredSnapshot>(
            storageKey: snapshotStorageDescriptors.previous.storageKey,
            defaultSelection: snapshotStorageDescriptors.previous.defaultSelection
        )

        let storedCurrentSnapshot = snapshotStore.codable(for: resolvedCurrentKey)
        let storedPreviousSnapshot = snapshotStore.codable(for: resolvedPreviousKey)

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
            for: resolvedCurrentKey
        )
        snapshotStore.setCodable(
            previousSnapshot,
            for: resolvedPreviousKey
        )

        return .init(
            currentKey: resolvedCurrentKey,
            previousKey: resolvedPreviousKey,
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
