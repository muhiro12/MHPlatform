import Foundation

final class StandardUpdateURLProtocol: URLProtocol {
    private enum Status {
        static let success = 200
        static let appID = 123
    }

    override static func canInit(with _: URLRequest) -> Bool {
        true
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url,
              let response = HTTPURLResponse(
                url: url, statusCode: Status.success, httpVersion: nil, headerFields: nil
              ) else {
            return
        }
        do {
            let data: Data
            if url.host == "itunes.apple.com" {
                let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
                guard components?.queryItems?.contains(.init(name: "id", value: String(Status.appID))) == true,
                      components?.queryItems?.contains(.init(name: "country", value: "us")) == true else {
                    throw URLError(.badURL)
                }
                data = Data(#"{"results":[{"trackId":123,"bundleId":"example.app","version":"2"}]}"#.utf8)
            } else {
                guard request.cachePolicy == .reloadIgnoringLocalCacheData else {
                    throw URLError(.badURL)
                }
                let document: [String: Any] = [
                    "schemaVersion": 1,
                    "revision": 1,
                    "bundleIdentifier": "example.app",
                    "requirement": ["minimumVersion": "2", "effectiveAt": "2001-01-01T00:00:00Z"]
                ]
                data = try JSONSerialization.data(withJSONObject: document)
            }
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {
        // Every stub completes synchronously.
    }
}
