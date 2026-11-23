import Foundation
import MHRemoteUpdate

/// The feature selection for apps using the shared configuration endpoint.
/// Each value is independently missing, invalid, or available.
public struct MHRemoteAppFeatures: Decodable, Sendable {
    public let announcements: MHRemoteConfigSection<MHAnnouncementFeed>
    public let remoteUpdate: MHRemoteConfigSection<MHRemoteUpdateSchedule.Feature>
}

public extension MHRemoteUpdateController {
    /// Uses one configuration request per refresh for updates and in-app announcements.
    /// The callback receives each decoded announcement section, even if the update section fails.
    /// Enqueue the observation synchronously. Transport and envelope failures deliver no section.
    /// Apps own presentation, read state, and offline retention.
    init(
        appStoreID: Int,
        configurationURL: URL,
        storefront: String? = nil,
        bundle: Bundle = .main,
        storageDirectory: URL? = nil,
        session: URLSession = .shared,
        onAnnouncements: @escaping @Sendable (MHRemoteConfigResponse<MHRemoteConfigSection<MHAnnouncementFeed>>) -> Void
    ) throws {
        let client = MHRemoteConfigClient(session: session)
        try self.init(
            appStoreID: appStoreID,
            configurationURL: configurationURL,
            storefront: storefront,
            bundle: bundle,
            storageDirectory: storageDirectory,
            session: session
        ) { url, identifier in
            let response = try await client.configuration(
                from: url, bundleIdentifier: identifier, features: MHRemoteAppFeatures.self
            )
            try Task.checkCancellation()
            onAnnouncements(response.map(\.features.announcements))
            return try response.map { document in
                try .init(bundleIdentifier: document.bundleIdentifier, feature: document.features.remoteUpdate.get())
            }
        }
    }
}
