import Foundation
import MHPreferences

/// Explicit migration of an app-owned legacy logging slot before logging starts.
public enum MHLogSnapshotMigration {
    /// Migration requires the app to resolve an occupied destination explicitly.
    public enum MigrationError: Error, Equatable, Sendable {
        case destinationOccupied
    }

    /// Builds a synchronous step that moves legacy events into the previous session slot.
    ///
    /// Accepts JSON `Data` containing an event array or the historical session
    /// envelope (`sessionIdentifier` and `events`). Both destination slots must
    /// be empty; existing snapshots are never replaced or merged. Missing source
    /// data is a no-op. Decode, encode, and destination conflicts throw, retaining
    /// the source. Run before constructing `MHLoggingBootstrap` or cleaning up
    /// the source domain. Callers own every key, domain, and stable step ID.
    public static func step(
        id: String,
        from source: MHLegacyStorageReference,
        to destination: MHLogSnapshotStorageDescriptors,
        store: MHPreferenceStore = .init()
    ) -> MHPreferenceMigrationStep {
        precondition(source.storageKey != destination.current.storageKey)
        precondition(source.storageKey != destination.previous.storageKey)
        let sourceDescriptor = MHCodablePreferenceDescriptor<LegacySnapshot>(
            storageKey: source.storageKey,
            defaultSelection: source.selection
        )
        let previousDescriptor = MHCodablePreferenceDescriptor<MHLogSessionSnapshotSink.StoredSnapshot>(
            storageKey: destination.previous.storageKey,
            defaultSelection: destination.previous.defaultSelection
        )
        return .synchronous(id: id) {
            guard let legacy = try store.codableResult(for: sourceDescriptor).get() else {
                return
            }
            guard store.contains(destination.current) == false,
                  store.contains(destination.previous) == false else {
                throw MigrationError.destinationOccupied
            }

            try store.setCodableResult(legacy.snapshot, for: previousDescriptor).get()
            store.remove(sourceDescriptor)
        }
    }
}

private extension MHLogSnapshotMigration {
    struct LegacySnapshot: Codable, Sendable {
        let snapshot: MHLogSessionSnapshotSink.StoredSnapshot

        init(from decoder: any Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let storedSnapshot = try? container.decode(MHLogSessionSnapshotSink.StoredSnapshot.self) {
                self.snapshot = storedSnapshot
            } else {
                self.snapshot = .init(
                    sessionIdentifier: UUID(),
                    events: try container.decode([MHLogEvent].self)
                )
            }
        }

        func encode(to encoder: any Encoder) throws {
            try snapshot.encode(to: encoder)
        }
    }
}
