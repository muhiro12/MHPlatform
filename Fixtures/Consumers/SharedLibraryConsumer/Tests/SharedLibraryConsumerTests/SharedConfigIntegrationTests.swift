import Foundation
import MHPlatformCore
import Testing

struct SharedConfigIntegrationTests {
    private struct Features: Decodable, Sendable {
        let first: MHRemoteConfigSection<Int>
        let second: MHRemoteConfigSection<Int>
    }

    @Test
    func theCoreUmbrellaSupportsIndependentFeatureDecodingWithoutExtraProducts() throws {
        let data = Data(#"""
            {"schemaVersion":1,"bundleIdentifier":"example.app","features":{"first":42,"second":"invalid"}}
        """#.utf8)
        let document = try MHRemoteConfigDocument<Features>.decode(data)
        #expect(try document.features.first.get() == 42)
        #expect(throws: DecodingError.self) {
            try document.features.second.get()
        }
    }
}
