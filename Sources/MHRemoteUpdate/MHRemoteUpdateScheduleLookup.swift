import Foundation
import MHRemoteConfig

/// Selects update policy through the shared app configuration transport and envelope.
public struct MHRemoteUpdateScheduleLookup: Sendable {
    private let client: MHRemoteConfigClient

    /// Uses the app's session, including its timeout and authentication configuration.
    public init(session: URLSession = .shared) {
        client = .init(session: session)
    }

    /// Fetches the update section, preserving the shared response's observation time.
    public func schedule(
        from url: URL,
        bundleIdentifier: String
    ) async throws -> MHRemoteConfigResponse<MHRemoteUpdateSchedule> {
        let response = try await client.configuration(
            from: url, bundleIdentifier: bundleIdentifier, features: RemoteUpdateFeatures.self
        )
        return try response.map { document in
            try .init(bundleIdentifier: document.bundleIdentifier, feature: document.features.remoteUpdate)
        }
    }
}
