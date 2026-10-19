import Foundation
import MHRemoteConfig
import Testing

struct MHRemoteConfigDocumentTests {
    private struct Features: Codable, Sendable {
        let first: Int
        let second: String
    }

    @Test
    func oneEnvelopeCanSupplyMultipleIndependentFeatureValues() throws {
        let data = Data(#"""
            {"schemaVersion":1,"bundleIdentifier":"example.app","features":{"first":42,"second":"value"}}
        """#.utf8)
        let document = try MHRemoteConfigDocument<Features>.decode(data)
        let fetchedAt = Date(timeIntervalSinceReferenceDate: 10)
        let response = MHRemoteConfigResponse(value: document, fetchedAt: fetchedAt)
        let first = response.map(\.features.first)
        let second = response.map(\.features.second)
        #expect(first.value == 42)
        #expect(second.value == "value")
        #expect(first.fetchedAt == fetchedAt)
        #expect(second.fetchedAt == fetchedAt)
        let decoded = try MHRemoteConfigDocument<Features>.decode(document.encoded())
        #expect(decoded.bundleIdentifier == "example.app")
        #expect(decoded.features.first == 42)
        #expect(decoded.features.second == "value")
    }

    @Test
    func unsupportedEnvelopeIsRejectedBeforeFeatureDecoding() {
        let data = Data(#"{"schemaVersion":2,"bundleIdentifier":"example.app","features":null}"#.utf8)
        #expect(throws: MHRemoteConfigError.unsupportedSchema) {
            try MHRemoteConfigDocument<Features>.decode(data)
        }
    }

    @Test(arguments: ["", " app", "app "])
    func invalidIdentityIsRejectedBeforeFeatureDecoding(_ identity: String) {
        let data = Data("""
            {"schemaVersion":1,"bundleIdentifier":"\(identity)","features":null}
            """.utf8)
        #expect(throws: MHRemoteConfigError.invalidDocument) {
            try MHRemoteConfigDocument<Features>.decode(data)
        }
    }
}
