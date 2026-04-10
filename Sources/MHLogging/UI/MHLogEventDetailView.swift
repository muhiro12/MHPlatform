#if canImport(SwiftUI)
import SwiftUI

struct MHLogEventDetailView: View {
    private enum Constants {
        static let metadataSpacing = 4.0
        static let verticalPadding = 2.0
    }

    let event: MHLogEvent

    var body: some View {
        List {
            summarySection
            messageSection
            sourceSection
            metadataSection
        }
        .navigationTitle("Log Event")
    }

    private var summarySection: some View {
        Section("Summary") {
            LabeledContent("Timestamp", value: event.timestamp.ISO8601Format())
            LabeledContent("Level", value: event.level.name.uppercased())
            LabeledContent("Subsystem", value: event.subsystem)
            LabeledContent("Category", value: event.category)
        }
    }

    private var messageSection: some View {
        Section("Message") {
            Text(event.message)
                .font(.body.monospaced())
                .logConsoleTextSelectionIfSupported()
        }
    }

    private var sourceSection: some View {
        Section("Source") {
            LabeledContent("File", value: event.source.file)
            LabeledContent("Function", value: event.source.function)
            LabeledContent("Line", value: "\(event.source.line)")
        }
    }

    @ViewBuilder private var metadataSection: some View {
        Section("Metadata") {
            if event.metadata.isEmpty {
                Text("No metadata")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(event.metadata.keys.sorted(), id: \.self) { key in
                    metadataRow(for: key)
                }
            }
        }
    }

    private func metadataRow(for key: String) -> some View {
        VStack(
            alignment: .leading,
            spacing: Constants.metadataSpacing
        ) {
            Text(key)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
            Text(event.metadata[key] ?? "")
                .font(.body.monospaced())
                .logConsoleTextSelectionIfSupported()
        }
        .padding(.vertical, Constants.verticalPadding)
    }
}
#endif
