import Foundation

final class ScheduleURLProtocol: URLProtocol {
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

    override func startLoading() {
        guard let url = request.url, request.cachePolicy == .reloadIgnoringLocalCacheData else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        let scenario = url.lastPathComponent
        if scenario == "offline" || scenario == "cancelled" {
            let code: URLError.Code = scenario == "offline" ? .notConnectedToInternet : .cancelled
            client?.urlProtocol(self, didFailWithError: URLError(code))
            return
        }
        let response: URLResponse
        if scenario == "nonHTTP" {
            response = .init(url: url, mimeType: nil, expectedContentLength: -1, textEncodingName: nil)
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
        let body: String
        switch scenario {
        case "decode":
            body = "invalid json"
        case "static":
            body = #"{"schemaVersion":2,"bundleIdentifier":"example.app","revision":2,"requirement":null}"#
        default:
            body = #"""
                {"schemaVersion":1,"bundleIdentifier":"example.app","revision":1,
                "issuedAt":"2026-10-18T00:00:00Z","validUntil":"2026-11-08T00:00:00Z",
                "requirement":{"minimumVersion":"6.0","effectiveAt":"2026-11-01T00:00:00Z"}}
            """#
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {
        // These synchronous fixtures leave no pending I/O.
    }
}
