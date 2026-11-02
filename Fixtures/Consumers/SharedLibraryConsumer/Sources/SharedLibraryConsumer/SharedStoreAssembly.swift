import Foundation
import SwiftData

/// App-owned example. Each process opens its own container from this declaration.
struct SharedStoreAssembly {
    let schema: Schema
    var migrationPlan: (any SchemaMigrationPlan.Type)?
    var groupIdentifier = "group.example.Journal"
    var relativePath = "Library/Application Support/Journal.store"
    var cloud: ModelConfiguration.CloudKitDatabase = .private("iCloud.example.Journal")
    var resolveGroup: (String) -> URL? = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier:)

    func host() throws -> ModelContainer {
        let url = try storeURL()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        return try .init(
            for: schema,
            migrationPlan: migrationPlan,
            configurations: [.init(schema: schema, url: url, cloudKitDatabase: cloud)]
        )
    }

    func extensionReader() throws -> ModelContainer {
        let url = try storeURL()
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw CocoaError(.fileReadNoSuchFile)
        }
        return try .init(
            for: schema,
            configurations: [.init(schema: schema, url: url, allowsSave: false, cloudKitDatabase: .none)]
        )
    }

    func preview() throws -> ModelContainer {
        try .init(
            for: schema,
            configurations: [.init(
                schema: schema,
                isStoredInMemoryOnly: true,
                groupContainer: .none,
                cloudKitDatabase: .none
            )]
        )
    }

    private func storeURL() throws -> URL {
        guard let group = resolveGroup(groupIdentifier) else {
            throw CocoaError(.fileReadNoPermission)
        }
        return group.appending(path: relativePath)
    }
}
