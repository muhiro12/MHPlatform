import Foundation

/// Relocates and cleans up store files addressed by caller-provided URLs.
public enum MHStoreRelocationService {
    /// Copies legacy store files into the current location when needed.
    @preconcurrency
    public static func relocateIfNeeded(
        plan: MHStoreRelocationPlan,
        fileManager: FileManager = .default,
        validateRelocatedStore: @Sendable (
            _ currentStoreURL: URL,
            _ copiedFileNames: [String]
        ) throws -> Void = { _, _ in
            // Intentionally empty.
        }
    ) throws -> MHStoreRelocationOutcome {
        guard try locationsAreDistinct(plan) else {
            return .skipped(.sameLocation)
        }
        let legacy = plan.legacyStoreURL
        let current = plan.currentStoreURL
        let legacyNames = try storeCandidateNames(fileManager: fileManager, storeURL: legacy)
        guard legacyNames.contains(legacy.lastPathComponent) else {
            return .skipped(.missingLegacyStore)
        }
        let currentNames = try storeCandidateNames(fileManager: fileManager, storeURL: current)
        return try install(
            plan: plan,
            legacyNames: legacyNames,
            currentNames: currentNames,
            fileManager: fileManager,
            validate: validateRelocatedStore
        )
    }

    private static func install(
        plan: MHStoreRelocationPlan,
        legacyNames: [String],
        currentNames: [String],
        fileManager: FileManager,
        validate: (URL, [String]) throws -> Void
    ) throws -> MHStoreRelocationOutcome {
        let current = plan.currentStoreURL
        let directory = current.deletingLastPathComponent()
        let workspace = directory.appending(path: ".relocation-" + UUID().uuidString, directoryHint: .isDirectory)
        let incoming = workspace.appending(path: "incoming", directoryHint: .isDirectory)
        let previous = workspace.appending(path: "previous", directoryHint: .isDirectory)
        try fileManager.createDirectory(at: incoming, withIntermediateDirectories: true)

        var canRemoveWorkspace = true
        defer {
            if canRemoveWorkspace {
                try? fileManager.removeItem(at: workspace)
            }
        }

        try fileManager.createDirectory(at: previous, withIntermediateDirectories: false)
        let destinationNames = try stage(legacyNames, from: plan, into: incoming, fileManager: fileManager)

        var backedUp = [String]()
        var installed = [String]()
        do {
            for name in currentNames {
                try fileManager.moveItem(at: directory.appending(path: name), to: previous.appending(path: name))
                backedUp.append(name)
            }
            for name in destinationNames {
                try fileManager.moveItem(at: incoming.appending(path: name), to: directory.appending(path: name))
                installed.append(name)
            }
            do {
                try validate(current, destinationNames)
            } catch {
                // Opening the copied store during validation can create additional sidecars.
                installed = try storeCandidateNames(fileManager: fileManager, storeURL: current)
                throw error
            }
        } catch {
            // Keep the backup available if the file system also refuses restoration.
            canRemoveWorkspace = false
            for name in installed.reversed() {
                let url = directory.appending(path: name)
                if fileManager.fileExists(atPath: url.path) {
                    try fileManager.removeItem(at: url)
                }
            }
            for name in backedUp {
                try fileManager.moveItem(at: previous.appending(path: name), to: directory.appending(path: name))
            }
            canRemoveWorkspace = true
            throw error
        }
        return .relocated(copiedFileNames: destinationNames, removedCurrentFileNames: currentNames)
    }

    /// Removes legacy store files after relocation succeeds.
    public static func removeLegacyStoreFilesIfNeeded(
        plan: MHStoreRelocationPlan,
        fileManager: FileManager = .default
    ) throws -> MHLegacyStoreCleanupOutcome {
        guard try locationsAreDistinct(plan) else {
            return .skipped(.sameLocation)
        }
        let legacy = plan.legacyStoreURL
        let names = try storeCandidateNames(fileManager: fileManager, storeURL: legacy)
        guard names.contains(legacy.lastPathComponent) else {
            return .skipped(.missingLegacyStore)
        }
        // Keep the main file until last so a failed sidecar removal can be retried.
        for name in names.reversed() {
            try fileManager.removeItem(at: legacy.deletingLastPathComponent().appending(path: name))
        }
        return .removed(fileNames: names)
    }
}

private extension MHStoreRelocationService {
    static func stage(
        _ legacyNames: [String],
        from plan: MHStoreRelocationPlan,
        into incoming: URL,
        fileManager: FileManager
    ) throws -> [String] {
        let legacy = plan.legacyStoreURL
        let currentName = plan.currentStoreURL.lastPathComponent
        return try legacyNames.map { name in
            let destination = currentName + name.dropFirst(legacy.lastPathComponent.count)
            try fileManager.copyItem(
                at: legacy.deletingLastPathComponent().appending(path: name),
                to: incoming.appending(path: destination)
            )
            return destination
        }
    }

    static func locationsAreDistinct(_ plan: MHStoreRelocationPlan) throws -> Bool {
        let legacy = plan.legacyStoreURL.resolvingSymlinksInPath().standardizedFileURL
        let current = plan.currentStoreURL.resolvingSymlinksInPath().standardizedFileURL
        if sameFile(legacy, current) {
            return false
        }
        if sameFile(legacy.deletingLastPathComponent(), current.deletingLastPathComponent()) {
            // A main file whose name matches the other store's sidecars belongs to both sets.
            let directory = legacy.deletingLastPathComponent()
            let values = try? directory.resourceValues(forKeys: [.volumeSupportsCaseSensitiveNamesKey])
            let caseSensitive = values?.volumeSupportsCaseSensitiveNames == true
            let legacyName = caseSensitive ? legacy.lastPathComponent : legacy.lastPathComponent.lowercased()
            let currentName = caseSensitive ? current.lastPathComponent : current.lastPathComponent.lowercased()
            if legacyName.hasPrefix(currentName + "-") || currentName.hasPrefix(legacyName + "-") {
                throw CocoaError(.fileWriteInvalidFileName)
            }
        }
        return true
    }

    static func sameFile(_ first: URL, _ second: URL) -> Bool {
        if first.path == second.path {
            return true
        }
        let keys: Set<URLResourceKey> = [.fileResourceIdentifierKey]
        guard let firstID = try? first.resourceValues(forKeys: keys).fileResourceIdentifier,
              let secondID = try? second.resourceValues(forKeys: keys).fileResourceIdentifier else {
            return false
        }
        return firstID.isEqual(secondID)
    }

    static func storeCandidateNames(fileManager: FileManager, storeURL: URL) throws -> [String] {
        let directory = storeURL.deletingLastPathComponent()
        guard fileManager.fileExists(atPath: directory.path) else {
            return []
        }
        let base = storeURL.lastPathComponent
        let names = try fileManager.contentsOfDirectory(atPath: directory.path)
        let candidates = try names.filter { name in
            guard name == base || name.hasPrefix(base + "-") else {
                return false
            }
            let url = directory.appending(path: name)
            let type = try fileManager.attributesOfItem(atPath: url.path)[.type] as? FileAttributeType
            if type == .typeDirectory {
                return false
            }
            guard type == .typeRegular else {
                throw CocoaError(.fileReadInvalidFileName, userInfo: [NSURLErrorKey: url])
            }
            return true
        }
        return candidates.sorted()
    }
}
