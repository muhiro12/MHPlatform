import Foundation
import MHRemoteConfig
import Testing

struct MHRemoteConfigSectionTests {
    private struct Features: Codable, Sendable {
        let first: MHRemoteConfigSection<Int>
        let second: MHRemoteConfigSection<Int>
    }

    private struct CancellingFeature: Decodable, Sendable {
        init(from _: any Decoder) throws {
            throw CancellationError()
        }
    }

    private struct TaskCancellingFeature: Decodable, Sendable {
        init(from _: any Decoder) {
            withUnsafeCurrentTask { task in
                task?.cancel()
            }
        }
    }

    @Test(arguments: [#""invalid""#, "null", "{}"])
    func invalidFeaturePreservesTheValidSiblingAndItsOriginalError(_ invalid: String) throws {
        let document = try decode(#"{"first":\#(invalid),"second":42}"#)
        #expect(try document.features.second.get() == 42)
        guard case let .invalid(error) = document.features.first else {
            Issue.record("Invalid content must stay distinct from a missing feature")
            return
        }
        #expect(error is DecodingError)
        #expect(throws: DecodingError.self) {
            try document.features.first.get()
        }
    }

    @Test
    func failuresAreIndependentInBothDirectionsAndMissingIsNeverAValidValue() throws {
        let missing = try decode(#"{"second":42}"#)
        #expect(try missing.features.second.get() == 42)
        guard case .missing = missing.features.first else {
            Issue.record("An absent key must remain a missing feature")
            return
        }
        #expect(throws: MHRemoteConfigSectionError.missing) {
            try missing.features.first.get()
        }
        let invalidSibling = try decode(#"{"first":7,"second":"invalid"}"#)
        #expect(try invalidSibling.features.first.get() == 7)
        #expect(throws: (any Error).self) {
            try invalidSibling.features.second.get()
        }
        let bothMissing = try decode("{}")
        #expect(throws: MHRemoteConfigSectionError.missing) {
            try bothMissing.features.second.get()
        }
    }

    @Test
    func validSectionsRoundTripButInvalidOrMissingSectionsCannotBeRepublished() throws {
        let valid = try decode(#"{"first":1,"second":2}"#)
        let roundTripped = try MHRemoteConfigDocument<Features>.decode(valid.encoded())
        #expect(try roundTripped.features.first.get() == 1)
        let invalid = try decode(#"{"first":1,"second":null}"#)
        #expect(throws: (any Error).self) {
            try invalid.encoded()
        }
        let missing = try decode(#"{"first":1}"#)
        #expect(throws: MHRemoteConfigSectionError.missing) {
            try missing.encoded()
        }
    }

    @Test
    func cancellationIsNotIsolatedIntoAnOrdinaryFeatureFailure() async {
        let data = Data("null".utf8)
        #expect(throws: CancellationError.self) {
            try JSONDecoder().decode(MHRemoteConfigSection<CancellingFeature>.self, from: data)
        }
        let task = Task {
            try JSONDecoder().decode(MHRemoteConfigSection<TaskCancellingFeature>.self, from: data)
        }
        await #expect(throws: CancellationError.self) {
            try await task.value
        }
        let missingTask = Task {
            withUnsafeCurrentTask { task in
                task?.cancel()
            }
            return try decode("{}")
        }
        await #expect(throws: CancellationError.self) {
            try await missingTask.value
        }
    }

    @Test(arguments: ["null", "[]", "invalid-json"])
    func invalidEnvelopeStillRejectsTheCompleteDocument(_ features: String) {
        #expect(throws: (any Error).self) {
            try decode(features)
        }
    }

    private func decode(_ features: String) throws -> MHRemoteConfigDocument<Features> {
        try .decode(Data("""
            {"schemaVersion":1,"bundleIdentifier":"example.app","features":\(features)}
            """.utf8))
    }
}
