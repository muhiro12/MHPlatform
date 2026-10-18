import Foundation

final class LookupURLProtocol: URLProtocol {
    private enum Status {
        static let success = 200
        static let unavailable = 503
    }

    override static func canInit(with _: URLRequest) -> Bool {
        true
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    private static func body(for scenario: String) -> String {
        switch scenario {
        case "empty":
            return #"{"results":[]}"#
        case "decode":
            return "invalid json"
        case "missingFields":
            return #"{"results":[{"trackId":123}]}"#
        case "appMismatch":
            return #"{"results":[{"trackId":124,"bundleId":"com.example.app","version":"2"}]}"#
        case "bundleMismatch":
            return #"{"results":[{"trackId":123,"bundleId":"com.example.other","version":"2"}]}"#
        case "invalidVersion":
            return #"{"results":[{"trackId":123,"bundleId":"com.example.app","version":"2-beta"}]}"#
        case "mixed":
            return #"""
                {"results":[
                {"trackId":124,"bundleId":"com.example.app","version":"9"},
                {"trackId":123,"bundleId":"com.example.app","version":"2.0"}
                ]}
            """#
        default:
            return #"{"results":[{"trackId":123,"bundleId":"com.example.app","version":"2.0"}]}"#
        }
    }

    override func startLoading() {
        guard let url = request.url,
              url.scheme == "https", url.host == "itunes.apple.com", url.path == "/lookup",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.queryItems?.contains(.init(name: "id", value: "123")) == true,
              components.queryItems?.contains(.init(name: "country", value: "jp")) == true else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        let scenario = request.value(forHTTPHeaderField: "Scenario") ?? "success"
        if scenario == "transport" || scenario == "cancelled" {
            let code: URLError.Code = scenario == "cancelled" ? .cancelled : .notConnectedToInternet
            client?.urlProtocol(self, didFailWithError: URLError(code))
            return
        }
        let response: URLResponse
        if scenario == "nonHTTP" {
            response = .init(url: url, mimeType: "application/json", expectedContentLength: -1, textEncodingName: nil)
        } else {
            guard let httpResponse = HTTPURLResponse(
                url: url,
                statusCode: scenario == "status" ? Status.unavailable : Status.success,
                httpVersion: nil,
                headerFields: nil
            ) else {
                return
            }
            response = httpResponse
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data((
            scenario == "publicationCache" && request.cachePolicy != .reloadIgnoringLocalCacheData
                ? #"{"results":[{"trackId":123,"bundleId":"com.example.app","version":"1"}]}"#
                : Self.body(for: scenario)
        ).utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {
        // Every stub completes synchronously, so there is no pending work to cancel.
    }
}
