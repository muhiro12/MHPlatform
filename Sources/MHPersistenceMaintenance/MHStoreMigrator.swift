import Foundation

/// Migrates and cleans up persisted store files.
public enum MHStoreMigrator {
    /// Copies legacy store files into the current location when needed.
    public static func migrateIfNeeded(
        plan: MHStoreMigrationPlan,
        fileManager: FileManager = .default
    ) throws -> MHStoreMigrationResult {
        guard plan.legacyStoreURL != plan.currentStoreURL else {
            return .skipped(.sameLocation)
        }
        guard fileManager.fileExists(atPath: plan.legacyStoreURL.path) else {
            return .skipped(.missingLegacyStore)
        }

        let legacyCandidateNames = try storeCandidateNames(
            fileManager: fileManager,
            storeURL: plan.legacyStoreURL
        )
        guard legacyCandidateNames.isEmpty == false else {
            return .skipped(.missingLegacyStore)
        }

        let currentCandidateNames = try storeCandidateNames(
            fileManager: fileManager,
            storeURL: plan.currentStoreURL
        )
        let cleanupCandidateNames = mergedCandidateNames(
            primaryCandidateNames: legacyCandidateNames,
            secondaryCandidateNames: currentCandidateNames
        )

        let removedCurrentFileNames = try removeStoreFilesIfExists(
            fileManager: fileManager,
            storeURL: plan.currentStoreURL,
            candidateNames: cleanupCandidateNames
        )
        let copiedFileNames = try copyStoreFiles(
            fileManager: fileManager,
            legacyURL: plan.legacyStoreURL,
            currentURL: plan.currentStoreURL,
            candidateNames: legacyCandidateNames
        )

        return .migrated(
            copiedFileNames: copiedFileNames,
            removedCurrentFileNames: removedCurrentFileNames
        )
    }

    /// Removes legacy store files after migration succeeds.
    public static func removeLegacyStoreFilesIfNeeded(
        plan: MHStoreMigrationPlan,
        fileManager: FileManager = .default
    ) throws -> MHStoreLegacyCleanupResult {
        guard plan.legacyStoreURL != plan.currentStoreURL else {
            return .skipped(.sameLocation)
        }
        guard fileManager.fileExists(atPath: plan.legacyStoreURL.path) else {
            return .skipped(.missingLegacyStore)
        }

        let legacyCandidateNames = try storeCandidateNames(
            fileManager: fileManager,
            storeURL: plan.legacyStoreURL
        )
        guard legacyCandidateNames.isEmpty == false else {
            return .skipped(.missingLegacyStore)
        }

        let removedFileNames = try removeStoreFilesIfExists(
            fileManager: fileManager,
            storeURL: plan.legacyStoreURL,
            candidateNames: legacyCandidateNames
        )

        return .removed(fileNames: removedFileNames)
    }
}

private extension MHStoreMigrator {
    static func storeCandidateNames(
        fileManager: FileManager,
        storeURL: URL
    ) throws -> [String] {
        let storeDirectoryURL = storeURL.deletingLastPathComponent()
        guard fileManager.fileExists(atPath: storeDirectoryURL.path) else {
            return []
        }

        let baseName = storeURL.lastPathComponent
        let directoryNames = try fileManager.contentsOfDirectory(atPath: storeDirectoryURL.path)
        let candidateNames = directoryNames.filter { name in
            guard name == baseName || name.hasPrefix(baseName + "-") else {
                return false
            }

            let candidateURL = storeDirectoryURL.appendingPathComponent(name)
            var isDirectory: ObjCBool = false
            let exists = fileManager.fileExists(
                atPath: candidateURL.path,
                isDirectory: &isDirectory
            )
            return exists && isDirectory.boolValue == false
        }

        return candidateNames.sorted()
    }

    static func copyStoreFiles(
        fileManager: FileManager,
        legacyURL: URL,
        currentURL: URL,
        candidateNames: [String]
    ) throws -> [String] {
        let legacyDirectoryURL = legacyURL.deletingLastPathComponent()
        let currentDirectoryURL = currentURL.deletingLastPathComponent()

        try fileManager.createDirectory(
            at: currentDirectoryURL,
            withIntermediateDirectories: true
        )

        var copiedDestinationURLs = [URL]()
        var copiedFileNames = [String]()

        do {
            for candidateName in candidateNames {
                let sourceURL = legacyDirectoryURL.appendingPathComponent(candidateName)
                let destinationURL = currentDirectoryURL.appendingPathComponent(candidateName)
                try fileManager.copyItem(at: sourceURL, to: destinationURL)
                copiedDestinationURLs.append(destinationURL)
                copiedFileNames.append(candidateName)
            }
        } catch {
            for copiedDestinationURL in copiedDestinationURLs.reversed() {
                try? fileManager.removeItem(at: copiedDestinationURL)
            }
            throw error
        }

        return copiedFileNames.sorted()
    }

    static func removeStoreFilesIfExists(
        fileManager: FileManager,
        storeURL: URL,
        candidateNames: [String]
    ) throws -> [String] {
        let storeDirectoryURL = storeURL.deletingLastPathComponent()

        var removedFileNames = [String]()

        for candidateName in candidateNames {
            let fileURL = storeDirectoryURL.appendingPathComponent(candidateName)
            guard fileManager.fileExists(atPath: fileURL.path) else {
                continue
            }
            try fileManager.removeItem(at: fileURL)
            removedFileNames.append(candidateName)
        }

        return removedFileNames.sorted()
    }

    static func mergedCandidateNames(
        primaryCandidateNames: [String],
        secondaryCandidateNames: [String]
    ) -> [String] {
        Array(
            Set(primaryCandidateNames).union(secondaryCandidateNames)
        )
        .sorted()
    }
}
