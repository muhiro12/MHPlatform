import Foundation

/// Resolves a public App Store version, validating both app and bundle identity.
public struct MHAppStoreVersionLookup: Sendable {
    /// Validation failures; transport and decoding failures retain their original errors.
    public enum Failure: Error, Equatable, Sendable {
        /// The app ID, bundle identifier, or two-letter storefront code is invalid.
        case invalidRequest
        /// The response is not HTTP.
        case invalidResponse
        /// The server returned a status outside 200 through 299.
        case httpStatus(Int)
        /// No result matches both expected identifiers.
        case identityMismatch
        /// The matching app's version is malformed.
        case invalidVersion
    }

    private enum Format {
        static let countryLength = 2
        static let uppercaseASCII: ClosedRange<UInt8> = 65...90
        static let lowercaseASCII: ClosedRange<UInt8> = 97...122
        static let successStatus = 200..<300
    }

    private struct App: Decodable {
        let trackId: Int
        let bundleId: String
        let version: String
    }

    private struct Response: Decodable {
        let results: [App]
    }

    private let session: URLSession

    /// Creates a lookup using the supplied session and its request configuration.
    public init(session: URLSession = .shared) {
        self.session = session
    }

    /// Looks up an app in the app-selected storefront; never substitutes another app.
    ///
    /// Cancellation propagates as `CancellationError`. No failure is converted into
    /// an update decision. Local HTTP cache is bypassed so rechecking does not
    /// renew old publication evidence. Store metadata does not guarantee download success.
    /// Nil omits country selection; the service's default is not a global catalog.
    public func version(
        appID: Int,
        bundleIdentifier: String,
        country: String? = nil
    ) async throws -> MHAppVersion {
        try Task.checkCancellation()
        let request = try makeRequest(appID: appID, bundleIdentifier: bundleIdentifier, country: country)
        do {
            let (data, urlResponse) = try await session.data(for: request)
            try Task.checkCancellation()
            guard let response = urlResponse as? HTTPURLResponse else {
                throw Failure.invalidResponse
            }
            guard Format.successStatus.contains(response.statusCode) else {
                throw Failure.httpStatus(response.statusCode)
            }
            let lookup = try JSONDecoder().decode(Response.self, from: data)
            guard let app = lookup.results.first(where: { app in
                app.trackId == appID && app.bundleId == bundleIdentifier
            }) else {
                throw Failure.identityMismatch
            }
            guard let version = MHAppVersion(app.version) else {
                throw Failure.invalidVersion
            }
            return version
        } catch {
            if error is CancellationError || Task.isCancelled || (error as? URLError)?.code == .cancelled {
                throw CancellationError()
            }
            throw error
        }
    }

    private func makeRequest(appID: Int, bundleIdentifier: String, country: String?) throws -> URLRequest {
        guard appID > 0,
              bundleIdentifier.isEmpty == false,
              bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines) == bundleIdentifier else {
            throw Failure.invalidRequest
        }
        if let country {
            guard country.utf8.count == Format.countryLength,
                  country.utf8.allSatisfy({ byte in
                    Format.uppercaseASCII.contains(byte) || Format.lowercaseASCII.contains(byte)
                  }) else {
                throw Failure.invalidRequest
            }
        }
        var components = URLComponents()
        components.scheme = "https"
        components.host = "itunes.apple.com"
        components.path = "/lookup"
        components.queryItems = [.init(name: "id", value: String(appID))]
        if let country {
            components.queryItems?.append(.init(name: "country", value: country.lowercased()))
        }
        guard let url = components.url else {
            throw Failure.invalidRequest
        }

        return .init(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
    }
}
