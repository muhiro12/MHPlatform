import Foundation
import MHLogging
import Testing

struct MHLogMetadataTests {
    private struct DemoError: Error, LocalizedError {
        var errorDescription: String? {
            "offline"
        }
    }

    @Test
    func metadata_drops_nil_values() {
        let metadata = MHLogMetadata.metadata(
            ("kept", "value"),
            ("dropped", nil)
        )

        #expect(metadata == ["kept": "value"])
    }

    @Test
    func merge_uses_later_values_for_duplicate_keys() {
        let metadata = MHLogMetadata.merge(
            [
                "id": "old",
                "first": "1"
            ],
            [
                "id": "new",
                "second": "2"
            ]
        )

        #expect(metadata == [
            "id": "new",
            "first": "1",
            "second": "2"
        ])
    }

    @Test
    func scalar_helpers_return_metadata_dictionaries() {
        let metadata = MHLogMetadata.merge(
            MHLogMetadata.bool("isEnabled", true),
            MHLogMetadata.count("count", 3),
            MHLogMetadata.presence("value", Optional("present")),
            MHLogMetadata.presence("missing", Optional<String>.none)
        )

        #expect(metadata == [
            "isEnabled": "true",
            "count": "3",
            "value": "present",
            "missing": "missing"
        ])
    }

    @Test
    func errorMetadata_uses_description_and_reflected_type() {
        let metadata = MHLogMetadata.errorMetadata(DemoError())

        #expect(metadata["error"] == "offline")
        #expect(metadata["errorType"] == "DemoError")
    }
}
