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
            let schedule = try MHRemoteUpdateSchedule.decode(data)
            guard schedule.bundleIdentifier == bundleIdentifier else {
                throw MHRemoteUpdateSchedule.Failure.identityMismatch
            }
            return schedule
        } catch {
            if error is CancellationError || Task.isCancelled || (error as? URLError)?.code == .cancelled {
                throw CancellationError()
            }
            throw error
        }
    }
}
