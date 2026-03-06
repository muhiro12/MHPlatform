import Foundation
import MHLogging
import Testing

struct MHJSONLLogSinkTests {
    private enum Constants {
        static let maximumFileSizeBytes = 100_000
        static let rotatingFileSizeBytes = 250
        static let longMessageLength = 120
    }

    @Test
    func write_appends_jsonl_lines() async throws {
        let fileManager = FileManager.default
        let directoryURL = temporaryDirectoryURL(name: "append")
        defer {
            try? fileManager.removeItem(at: directoryURL)
        }
        let fileURL = directoryURL.appendingPathComponent("events.jsonl")
        let sink = MHJSONLLogSink(
            fileURL: fileURL,
            maximumFileSizeBytes: Constants.maximumFileSizeBytes
        )

        await sink.write(makeEvent(index: 1))
        await sink.write(makeEvent(index: 2))

        let text = try String(contentsOf: fileURL, encoding: .utf8)
        let lines = text.split(whereSeparator: \.isNewline)
        #expect(lines.count == 2)
    }

    @Test
    func loadEvents_restores_after_reinitialization() async {
        let fileManager = FileManager.default
        let directoryURL = temporaryDirectoryURL(name: "restore")
        defer {
            try? fileManager.removeItem(at: directoryURL)
        }
        let fileURL = directoryURL.appendingPathComponent("events.jsonl")

        let firstSink = MHJSONLLogSink(
            fileURL: fileURL,
            maximumFileSizeBytes: Constants.maximumFileSizeBytes
        )
        await firstSink.write(makeEvent(index: 1))
        await firstSink.write(makeEvent(index: 2))

        let secondSink = MHJSONLLogSink(
            fileURL: fileURL,
            maximumFileSizeBytes: Constants.maximumFileSizeBytes
        )
        let loadedEvents = await secondSink.loadEvents()

        #expect(loadedEvents.count == 2)
        #expect(loadedEvents.map(\.message) == ["jsonl-1", "jsonl-2"])
    }

    @Test
    func write_rotates_when_file_size_limit_is_exceeded() async {
        let fileManager = FileManager.default
        let directoryURL = temporaryDirectoryURL(name: "rotate")
        defer {
            try? fileManager.removeItem(at: directoryURL)
        }
        let fileURL = directoryURL.appendingPathComponent("events.jsonl")
        let sink = MHJSONLLogSink(
            fileURL: fileURL,
            maximumFileSizeBytes: Constants.rotatingFileSizeBytes
        )

        await sink.write(makeEvent(index: 1, message: longMessage(seed: "a")))
        await sink.write(makeEvent(index: 2, message: longMessage(seed: "b")))
        await sink.write(makeEvent(index: 3, message: longMessage(seed: "c")))

        let archivedFileURL = fileURL.appendingPathExtension("1")
        #expect(fileManager.fileExists(atPath: fileURL.path))
        #expect(fileManager.fileExists(atPath: archivedFileURL.path))
    }
}

private extension MHJSONLLogSinkTests {
    func temporaryDirectoryURL(name: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("MHJSONLLogSinkTests")
            .appendingPathComponent(name)
            .appendingPathComponent(UUID().uuidString)
    }

    func longMessage(seed: String) -> String {
        .init(repeating: seed, count: Constants.longMessageLength)
    }

    func makeEvent(
        index: Int,
        message: String? = nil
    ) -> MHLogEvent {
        MHLogEvent(
            level: .info,
            subsystem: "tests.jsonl",
            category: "sink",
            message: message ?? "jsonl-\(index)",
            source: .init(
                file: "MHJSONLLogSinkTests.swift",
                function: "makeEvent",
                line: index
            ),
            timestamp: .init(timeIntervalSince1970: Double(index)),
            metadata: ["index": "\(index)"]
        )
    }
}
