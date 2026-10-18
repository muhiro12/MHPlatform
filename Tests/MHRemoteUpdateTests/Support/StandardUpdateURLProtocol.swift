import Foundation

final class StandardUpdateURLProtocol: URLProtocol {
    private enum Status {
        static let success = 200
        static let appID = 123
        static let validity: TimeInterval = 3_600
        static let issueLead: TimeInterval = 60
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
                      components?.queryItems?.contains(.init(name: "country", value: "jp")) == true else {
                    throw URLError(.badURL)
                }
                data = Data(#"{"results":[{"trackId":123,"bundleId":"example.app","version":"2"}]}"#.utf8)
            } else {
                let formatter = ISO8601DateFormatter()
                let issuedAt = formatter.string(from: .now.addingTimeInterval(-Status.issueLead))
                let document: [String: Any] = [
                    "schemaVersion": 1,
                    "revision": 1,
                    "bundleIdentifier": "example.app",
                    "issuedAt": issuedAt,
                    "validUntil": formatter.string(from: .now.addingTimeInterval(Status.validity)),
                    "requirement": ["minimumVersion": "2", "effectiveAt": issuedAt]
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
