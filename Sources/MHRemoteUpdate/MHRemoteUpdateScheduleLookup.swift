import Foundation

/// Loads the shared schedule format from an app-selected HTTPS endpoint.
public struct MHRemoteUpdateScheduleLookup: Sendable {
    /// Transport and decoding errors propagate; these cases describe response validation.
    public enum Failure: Error, Equatable, Sendable {
        /// A secure endpoint and nonempty expected identity are required.
        case invalidRequest
        /// A non-HTTP response cannot establish policy.
        case invalidResponse
        /// The server returned a status outside 200 through 299.
        case httpStatus(Int)
    }

    private enum Status {
        static let success = 200..<300
    }

    private let session: URLSession

    /// Uses the app's session, including its timeout and authentication configuration.
    public init(session: URLSession = .shared) {
        self.session = session
    }

    /// Fetches an identity-validated document without storing it or selecting a release policy.
    ///
    /// Bypasses the local response cache. Document validity is still checked separately
    /// by the controller; a successful response never extends its absolute expiry.
    public func schedule(from url: URL, bundleIdentifier: String) async throws -> MHRemoteUpdateSchedule {
        let schedule = try MHRemoteUpdateSchedule.decode(await fetch(from: url, bundleIdentifier: bundleIdentifier))
        guard schedule.bundleIdentifier == bundleIdentifier else {
            throw MHRemoteUpdateSchedule.Failure.identityMismatch
        }
        return schedule
    }

    /// Fetches schema v2 without assigning freshness to local cache reads.
    public func staticPolicy(from url: URL, bundleIdentifier: String) async throws -> MHRemoteUpdateStaticPolicy {
        let policy = try MHRemoteUpdateStaticPolicy.decode(await fetch(from: url, bundleIdentifier: bundleIdentifier))
        guard policy.bundleIdentifier == bundleIdentifier else {
            throw MHRemoteUpdateSchedule.Failure.identityMismatch
        }
        return policy
    }

    func document(from url: URL, bundleIdentifier: String) async throws -> MHRemoteUpdateDocument {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let document = try decoder.decode(
            MHRemoteUpdateDocument.self, from: await fetch(from: url, bundleIdentifier: bundleIdentifier)
        )
        guard document.bundleIdentifier == bundleIdentifier else {
            throw MHRemoteUpdateSchedule.Failure.identityMismatch
        }
        return document
    }

    private func fetch(from url: URL, bundleIdentifier: String) async throws -> Data {
        try Task.checkCancellation()
        guard url.scheme == "https", url.host?.isEmpty == false,
              bundleIdentifier.isEmpty == false else {
            throw Failure.invalidRequest
        }
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        do {
            let (data, urlResponse) = try await session.data(for: request)
            try Task.checkCancellation()
            guard let response = urlResponse as? HTTPURLResponse else {
                throw Failure.invalidResponse
            }
            guard Status.success.contains(response.statusCode) else {
                throw Failure.httpStatus(response.statusCode)
            }
            return data
        } catch {
            if error is CancellationError || Task.isCancelled || (error as? URLError)?.code == .cancelled {
                throw CancellationError()
            }
            throw error
        }
    }
}
