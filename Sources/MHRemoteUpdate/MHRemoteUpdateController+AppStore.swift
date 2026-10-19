import Foundation

public extension MHRemoteUpdateController {
    /// Shared MH conventions for the standard App Store integration.
    enum Defaults {
        private static let secondsPerDay: TimeInterval = 86_400
        private static let maximumValidityDays: TimeInterval = 30

        /// The standard metadata storefront; apps may explicitly select another country.
        public static let storefront = "jp"
        /// The maximum accepted policy-document lifetime, including advance announcement.
        public static let maximumValidity = maximumValidityDays * secondsPerDay
        /// Maximum offline reuse of a successfully fetched static policy.
        public static let policyLifetime = maximumValidityDays * secondsPerDay
        /// The lifetime of successful publication evidence.
        public static let publicationLifetime = secondsPerDay
    }

    /// Assembles lookups, version identity, storage, and standard lifetimes for an App Store app.
    ///
    /// Only the policy endpoint and App Store ID are required in an app process.
    /// Bundle.main supplies identity/version. Extensions must pass the containing
    /// app's bundle, or use the injectable initializer for app-owned identity providers.
    /// Storage is scoped by bundle, app ID, and storefront under Application Support;
    /// supplying a directory supports App Groups, alternate environments, and tests.
    /// Call `prepare()` at startup/foreground to restore and refresh the policy.
    init(
        appStoreID: Int,
        policyURL: URL,
        storefront: String = Defaults.storefront,
        bundle: Bundle = .main,
        storageDirectory: URL? = nil,
        session: URLSession = .shared
    ) throws {
        guard appStoreID > 0,
              policyURL.scheme == "https", policyURL.host?.isEmpty == false,
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
            .appendingPathComponent(storefront.lowercased(), isDirectory: true)
            .appendingPathComponent("snapshot.json")
        let scheduleLookup = MHRemoteUpdateScheduleLookup(session: session)
        let versionLookup = MHAppStoreVersionLookup(session: session)
        let installedVersion = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        try self.init(
            bundleIdentifier: bundleIdentifier,
            storefront: storefront,
            maximumValidity: Defaults.maximumValidity,
            policyLifetime: Defaults.policyLifetime,
            publicationLifetime: Defaults.publicationLifetime,
            store: .init(fileURL: fileURL, sourceURL: policyURL),
            currentVersion: { installedVersion },
            now: Date.init,
            fetchDocument: {
                try await scheduleLookup.document(from: policyURL, bundleIdentifier: bundleIdentifier)
            },
            publicVersion: {
                try await versionLookup.version(
                    appID: appStoreID, bundleIdentifier: bundleIdentifier, country: storefront
                )
            }
        )
    }
}
