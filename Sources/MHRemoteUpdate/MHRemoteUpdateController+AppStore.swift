import Foundation

public extension MHRemoteUpdateController {
    /// Shared MH conventions for the standard App Store integration.
    enum Defaults {
        private static let secondsPerDay: TimeInterval = 86_400
        private static let policyLifetimeDays: TimeInterval = 30

        /// Maximum offline reuse of a successfully fetched policy.
        public static let policyLifetime = policyLifetimeDays * secondsPerDay
        /// The lifetime of successful publication evidence.
        public static let publicationLifetime = secondsPerDay
    }

    /// Assembles lookups, version identity, storage, and standard lifetimes for an App Store app.
    ///
    /// Only the app configuration endpoint and App Store ID are required in an app process.
    /// Bundle.main supplies identity/version. Extensions must pass the containing
    /// app's bundle, or use the injectable initializer for app-owned identity providers.
    /// Storage is scoped by bundle, app ID, and storefront under Application Support;
    /// supplying a directory supports App Groups, alternate environments, and tests.
    /// Call `prepare()` at startup/foreground to restore and refresh the policy.
    init(
        appStoreID: Int,
        configurationURL: URL,
        storefront: String? = nil,
        bundle: Bundle = .main,
        storageDirectory: URL? = nil,
        session: URLSession = .shared
    ) throws {
        guard appStoreID > 0,
              configurationURL.scheme == "https", configurationURL.host?.isEmpty == false,
              let bundleIdentifier = bundle.bundleIdentifier,
              bundleIdentifier.isEmpty == false,
              bundleIdentifier.contains("/") == false,
              bundleIdentifier != ".", bundleIdentifier != ".." else {
            throw Failure.invalidConfiguration
        }
        let directory = storageDirectory ?? URL.applicationSupportDirectory
            .appendingPathComponent("MHRemoteUpdate", isDirectory: true)
        let fileURL = directory
            .appendingPathComponent(bundleIdentifier, isDirectory: true)
            .appendingPathComponent(String(appStoreID), isDirectory: true)
            .appendingPathComponent(storefront?.lowercased() ?? "default", isDirectory: true)
            .appendingPathComponent("snapshot.json")
        let scheduleLookup = MHRemoteUpdateScheduleLookup(session: session)
        let versionLookup = MHAppStoreVersionLookup(session: session)
        let installedVersion = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        try self.init(
            bundleIdentifier: bundleIdentifier,
            storefront: storefront,
            policyLifetime: Defaults.policyLifetime,
            publicationLifetime: Defaults.publicationLifetime,
            store: .init(fileURL: fileURL, sourceURL: configurationURL),
            currentVersion: { installedVersion },
            now: Date.init,
            fetchSchedule: {
                try await scheduleLookup.schedule(from: configurationURL, bundleIdentifier: bundleIdentifier)
            },
            publicVersion: {
                try await versionLookup.version(
                    appID: appStoreID, bundleIdentifier: bundleIdentifier, country: storefront
                )
            }
        )
    }
}
