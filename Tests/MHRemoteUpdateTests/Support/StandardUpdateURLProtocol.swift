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
                let country = components?.queryItems?.first { $0.name == "country" }?.value
                let expected = request.value(forHTTPHeaderField: "X-Expected-Storefront") ?? "default"
                guard components?.queryItems?.contains(.init(name: "id", value: String(Status.appID))) == true,
                      country == (expected == "default" ? nil : expected) else {
                    throw URLError(.badURL)
                }
                data = Data(#"{"results":[{"trackId":123,"bundleId":"example.app","version":"2"}]}"#.utf8)
            } else {
                guard request.cachePolicy == .reloadIgnoringLocalCacheData else {
                    throw URLError(.badURL)
                }
                data = try configuration(for: url.lastPathComponent)
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

    private func configuration(for scenario: String) throws -> Data {
        var features: [String: Any] = [
            "remoteUpdate": [
                "schemaVersion": 1, "revision": 1,
                "requirement": ["minimumVersion": "2", "effectiveAt": "2001-01-01T00:00:00Z"]
            ]
        ]
        switch scenario {
        case "offline":
            throw URLError(.notConnectedToInternet)
        case "bad-announcements":
            features["announcements"] = NSNull()
        case "valid", "bad-update":
            features["announcements"] = [
                "schemaVersion": 1, "defaultLanguage": "ja",
                "items": [["id": "news", "localizations": ["ja": ["title": "更新", "body": "詳細"]]]]
            ]
            if scenario == "bad-update" {
                features["remoteUpdate"] = NSNull()
            }
        default:
            break
        }
        return try JSONSerialization.data(withJSONObject: [
            "schemaVersion": 1, "bundleIdentifier": scenario == "wrong-app" ? "other.app" : "example.app",
            "features": features
        ])
    }
}
