import Foundation

/// Loads typed app configuration from an app-selected HTTPS endpoint.
///
/// Transport and envelope decoding are shared. This client installs no timer,
/// UI, remote hosting convention, or feature-specific cache policy.
public struct MHRemoteConfigClient: Sendable {
    private enum Status {
        static let success = 200..<300
    }

    private let session: URLSession

    /// Uses the app's session, including its timeout and authentication configuration.
    public init(session: URLSession = .shared) {
        self.session = session
    }

    /// Fetches one identity-validated envelope for the selected feature decoding type.
    ///
    /// Local HTTP cache is bypassed. Reuse the returned response across features
    /// rather than fetching the same URL separately. Cancellation always throws.
    public func configuration<Features: Decodable & Sendable>(
        from url: URL,
        bundleIdentifier: String,
        features _: Features.Type
    ) async throws -> MHRemoteConfigResponse<MHRemoteConfigDocument<Features>> {
        try Task.checkCancellation()
        guard url.scheme == "https", url.host?.isEmpty == false,
              bundleIdentifier.isEmpty == false,
              bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines) == bundleIdentifier else {
            throw MHRemoteConfigError.invalidRequest
        }
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        do {
            let (data, urlResponse) = try await session.data(for: request)
            let fetchedAt = Date()
            try Task.checkCancellation()
            guard let response = urlResponse as? HTTPURLResponse else {
                throw MHRemoteConfigError.invalidResponse
            }
            guard Status.success.contains(response.statusCode) else {
                throw MHRemoteConfigError.httpStatus(response.statusCode)
            }
            let document = try MHRemoteConfigDocument<Features>.decode(data)
            guard document.bundleIdentifier == bundleIdentifier else {
                throw MHRemoteConfigError.identityMismatch
            }
            try Task.checkCancellation()
            return .init(value: document, fetchedAt: fetchedAt)
        } catch {
            if error is CancellationError || Task.isCancelled || (error as? URLError)?.code == .cancelled {
                throw CancellationError()
            }
            throw error
        }
    }
}
