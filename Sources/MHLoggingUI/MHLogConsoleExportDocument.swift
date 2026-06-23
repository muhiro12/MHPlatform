#if canImport(SwiftUI) && !os(watchOS)
import SwiftUI
import UniformTypeIdentifiers

struct MHLogConsoleExportDocument: FileDocument {
    static var readableContentTypes: [UTType] {
        [.plainText]
    }

    var jsonLines: String

    init(jsonLines: String) {
        self.jsonLines = jsonLines
    }

    init(configuration: ReadConfiguration) {
        let data = configuration.file.regularFileContents ?? .init()
        jsonLines = String(data: data, encoding: .utf8) ?? .init()
    }

    func fileWrapper(configuration _: WriteConfiguration) -> FileWrapper {
        .init(regularFileWithContents: Data(jsonLines.utf8))
    }
}
#endif
